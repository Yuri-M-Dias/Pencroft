library(data.table)
library(xgboost)

data.train <- fread("../input/train.csv", header = TRUE, colClasses = "numeric", 
    showProgress = FALSE)
data.train$set <- "train"

data.test <- fread("../input/test.csv", header = TRUE, colClasses = "numeric", 
    showProgress = FALSE)
data.test$target <- NA
data.test$set <- "test"

data.bind <- rbind(data.train, data.test[, colnames(data.train), with = FALSE])
rm(data.test)

target.cols <- c("f190486d6", "58e2e02e6", "eeb9cd3aa", "9fd594eec", "6eef030c1", 
    "15ace8c9f", "fb0f5dbfe", "58e056e12", "20aa07010", "024c577b9", "d6bb78916", 
    "b43a7cfd5", "58232a6fb", "1702b5bf0", "324921c7b", "62e59a501", "2ec5b290f", 
    "241f0f867", "fb49e4212", "66ace2992", "f74e8f13d", "5c6487af1", "963a49cdc", 
    "26fc93eb7", "1931ccfdd", "703885424", "70feb1494", "491b9ee45", "23310aa6f", 
    "e176a204a", "6619d81fc", "1db387535", "fc99f9426", "91f701ba2", "0572565c2", 
    "190db8488", "adb64ff71", "c47340d97", "c5a231d81", "0ff32eb98")

cat("##### find leaky rows and columns #####\n")

# initial leaky columns
leaky.cols <- data.table(latest = target.cols[1], col = target.cols, lag = 0:39)

for (iter in 1:2) {
    cat("iter:", iter, "\n")
    
    leaky.rows <- data.table()
    for (i in 1:39) {
        temp <- merge(leaky.cols, leaky.cols[, .(latest, lag = lag + i, 
            col)], by = c("latest", "lag"))
        key.x <- temp$col.x
        key.y <- temp$col.y
        
        if (iter == 1) {
            valid.rows <- which(sapply(apply(data.bind[, key.x, with = FALSE], 
                1, unique), length) > ifelse(data.bind$set == "train", 2, 
                3))
        } else if (iter == 2) {
            valid.rows <- which(apply(data.bind[, key.x, with = FALSE] > 
                0, 1, sum) > 0)
        }
        
        leaky.rows.temp <- merge(data.bind[valid.rows, c("set", key.x, "ID", 
            "target"), with = FALSE], data.bind[, c("set", key.y, "ID"), 
            with = FALSE], by.x = c("set", key.x), by.y = c("set", key.y), 
            suffixes = c("", "_prev"), allow.cartesian = TRUE)
        
        if (nrow(leaky.rows.temp) > 0) {
            leaky.rows.temp <- leaky.rows.temp[, .(ID, target, ID_prev, 
                lag = i)]
            # omit leaks which have already been found
            leaky.rows.temp <- leaky.rows.temp[!(ID %in% leaky.rows$ID | 
                ID_prev %in% leaky.rows$ID_prev)]
            # concat
            leaky.rows <- rbind(leaky.rows, leaky.rows.temp)
        }
    }
    
    # omit confusing leaks
    omit.ID <- leaky.rows[, .N, by = .(ID, lag)][N > 1]$ID
    omit.ID_prev <- leaky.rows[, .N, by = .(ID_prev, lag)][N > 1]$ID_prev
    leaky.rows <- leaky.rows[!(ID %in% omit.ID | ID_prev %in% omit.ID_prev)]
    
    # find the first row for each customer
    leaky.rows[, `:=`(ID_first, ID_prev)]
    while (TRUE) {
        temp <- merge(leaky.rows[, .(ID_first)], leaky.rows[, .(ID, ID_first, 
            lag)], by.x = "ID_first", by.y = "ID", all.x = TRUE, sort = FALSE)
        if (sum(!is.na(temp$lag)) > 0) {
            leaky.rows$ID_first[!is.na(temp$lag)] <- temp[[2]][!is.na(temp$lag)]
            leaky.rows$lag[!is.na(temp$lag)] <- leaky.rows$lag[!is.na(temp$lag)] + 
                temp$lag[!is.na(temp$lag)]
            leaky.rows[lag > 1e+06, `:=`(lag, NA)]
        } else {
            break
        }
    }
    leaky.rows <- leaky.rows[!is.na(lag), .(ID, target, ID_first, lag)]
    
    temp <- data.bind[ID %in% leaky.rows$ID_first, .(ID, target, ID_first = ID, 
        lag = 0)]
    leaky.rows <- rbind(leaky.rows, temp)[order(ID_first, lag)]
    
    # get the target values by leaks
    leaky.rows[, `:=`(target.leak, NA)]
    leaky.rows <- merge(leaky.rows, data.bind[, c("ID", target.cols), with = FALSE], 
        by = "ID", sort = FALSE)
    for (i in 1:40) {
        temp <- merge(leaky.rows[, .(ID_first, lag = lag + 1 + i)], leaky.rows[, 
            c("ID_first", "lag", target.cols[i]), with = FALSE], by = c("ID_first", 
            "lag"), all.x = TRUE, sort = FALSE)
        leaky.rows$target.leak <- ifelse(is.na(leaky.rows$target.leak), 
            temp[[target.cols[i]]], leaky.rows$target.leak)
    }
    
    temp <- leaky.rows[!is.na(target)]
    temp[, `:=`(error, abs(target - target.leak))]
    cat("\ttrain:\t", sum(!is.na(temp$target.leak)), "leaks are found,", 
        sum(temp$error == 0, na.rm = TRUE), "leaks are correct\n")
    temp <- leaky.rows[is.na(target)]
    cat("\ttest:\t", sum(!is.na(temp$target.leak)), "leaks are found\n")
    
    ##### find more leaky columns by leaky rows #####
    
    before <- merge(data.bind[, !"set", with = FALSE], leaky.rows[, .(ID_first, 
        lag, ID)], by = "ID")
    before <- merge(before, leaky.rows[, .(ID_first, lag = lag - 1)], by = c("ID_first", 
        "lag"))[order(ID_first, lag)]
    after <- merge(data.bind[, !"set", with = FALSE], leaky.rows[, .(ID_first, 
        lag = lag - 1, ID)], by = "ID")
    after <- merge(after, leaky.rows[, .(ID_first, lag)], by = c("ID_first", 
        "lag"))[order(ID_first, lag)]
    
    nonzero.before <- apply(before > 0, 2, sum)[-(1:4)]
    nonzero.after <- apply(after > 0, 2, sum)[-(1:4)]
    
    leaky.cols <- data.table(col = names(nonzero.before), nonzero = nonzero.before, 
        latest = "", lag = 0)
    valid.cols <- leaky.cols[nonzero.before > 10]$col
    
    log <- data.table()
    for (col1 in valid.cols) {
        
        if (leaky.cols[col == col1]$latest != "") 
            {
                next
            }  # already processed
        
        # find the latest column of col1
        latest_of_col1 <- col1
        updated <- TRUE
        while (updated) {
            updated <- FALSE
            cand.vars <- names(nonzero.before)[which(nonzero.before == nonzero.after[latest_of_col1])]
            temp <- c()
            for (col2 in cand.vars) {
                if (sum(before[[col2]] != after[[latest_of_col1]]) == 0) {
                  temp <- c(temp, col2)
                }
            }
            if (length(temp) == 1) {
                updated <- TRUE
                latest_of_col1 <- temp
            }
        }
        
        leaky.cols[col == latest_of_col1]$latest <- latest_of_col1
        
        # find group columns of col1
        group_of_col1 <- latest_of_col1
        lag <- 0
        updated <- TRUE
        while (updated) {
            updated <- FALSE
            cand.vars <- names(nonzero.after)[which(nonzero.before[group_of_col1] == 
                nonzero.after)]
            temp <- c()
            for (col2 in cand.vars) {
                if (sum(before[[group_of_col1]] != after[[col2]]) == 0) {
                  temp <- c(temp, col2)
                }
            }
            if (length(temp) == 1) {
                updated <- TRUE
                group_of_col1 <- temp
                lag <- lag + 1
                leaky.cols[col == group_of_col1]$latest <- latest_of_col1
                leaky.cols[col == group_of_col1]$lag <- lag
            }
        }
    }
    
    leaky.cols <- leaky.cols[latest %in% leaky.cols[lag > 0]$latest][order(latest, 
        lag)]
    cat("\tFound", length(unique(leaky.cols$latest)), "column groups (total", 
        nrow(leaky.cols), "columns)\n")
}

write.csv(leaky.rows, "leaky_rows.csv", row.names = FALSE)
write.csv(leaky.cols, "leaky_cols.csv", row.names = FALSE)

cat("##### reconstruction of datasets #####\n")

data.bind[data.bind == 0] <- NA

data.train <- merge(data.bind[set == "train"], leaky.rows[, .(ID, target.leak)], 
    by = "ID", all.x = TRUE, sort = FALSE)
data.test <- merge(data.bind[set == "test"], leaky.rows[, .(ID, target.leak)], 
    by = "ID", all.x = TRUE, sort = FALSE)
rm(data.bind)

# add leaky rows of test data to training data
data.test[30000 <= target.leak & target.leak <= 4e+07, `:=`(target, target.leak)]
data.train <- rbind(data.train, data.test[!is.na(target)])
data.train[, `:=`(target, log(target + 1))]

cat("##### feature engineering #####\n")

temp <- leaky.cols[, .(nonzero_max = max(nonzero)), by = latest][order(-nonzero_max)]
for (i in 1:50) {
    cols <- leaky.cols[latest %in% temp$latest[i]]$col
    data.train[[paste0("mean_", i)]] <- apply(data.train[, cols, with = FALSE], 
        1, mean, na.rm = TRUE)
    data.test[[paste0("mean_", i)]] <- apply(data.test[, cols, with = FALSE], 
        1, mean, na.rm = TRUE)
    data.train[[paste0("logmean_", i)]] <- apply(log(data.train[, cols, 
        with = FALSE] + 1), 1, mean, na.rm = TRUE)
    data.test[[paste0("logmean_", i)]] <- apply(log(data.test[, cols, with = FALSE] + 
        1), 1, mean, na.rm = TRUE)
}

exp.vars <- c(target.cols, paste0("mean_", c(1:50)), paste0("logmean_", 
    c(1:50)))

params <- list(eta = 0.01, gamma = 0, max_depth = 10, min_child_weight = 8, 
    max_delta_step = 0, subsample = 0.8, colsample_bytree = 1, colsample_bylevel = 0.2, 
    lambda = 1, alpha = 1, objective = "reg:linear", eval_metric = "rmse", 
    base_score = mean(data.train$target))

cat("##### XGBoost #####\n")

for (seed in 0:9) {
    cat("iter:", seed + 1, "\n")
    
    x.train <- data.train[, exp.vars, with = FALSE]
    x.train <- apply(x.train, 2, as.numeric)
    y.train <- data.train$target
    dtrain <- xgb.DMatrix(data = as.matrix(x.train), label = y.train)
    rm(x.train)
    
    x.test <- data.test[, exp.vars, with = FALSE]
    x.test <- apply(x.test, 2, as.numeric)
    
    set.seed(seed)
    model.xgb <- xgb.train(params = params, data = dtrain, nrounds = 450, 
        verbose = FALSE, nthread = 4)
    
    result.temp <- cbind(data.test[, .(ID, target.leak)], pred = predict(model.xgb, 
        as.matrix(x.test)))
    if (seed == 0) {
        result <- result.temp
    } else {
        result$pred <- result$pred + result.temp$pred
    }
}

cat("##### make submission #####\n")

result[, `:=`(pred, pred/(seed + 1))]
submission <- result[, .(ID, target.leak, target = pred)]
submission[, `:=`(target, round(exp(target) - 1))]
submission[, `:=`(target, ifelse(is.na(target.leak), target, target.leak))]
write.csv(submission[, .(ID, target)], "submission.csv", row.names = FALSE)
