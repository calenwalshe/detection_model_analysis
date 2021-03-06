#' Compute error rate for a target distribution given an arbitrary 3D decision surface
#'
#' @param mod_mean1 
#' @param mod_mean2 
#' @param mod_cov1 
#' @param mod_cov2 
#' @param target_mean 
#' @param target_cov 
#' @param resolution 
#' @param pr_a 
#'
#' @return
#' @export
#'
#' @examples
polar.error <- function(mod_mean1, mod_mean2, mod_cov1, mod_cov2, target_mean, target_cov, vals, pr_a = .5) {
  
  mod_mean1 <- mod_mean1 - target_mean
  mod_mean2 <- mod_mean2 - target_mean
  
  target_mean <- c(0,0,0)
  
  L <- solve(t(chol(target_cov)))
  
  target_cov_delt <- L %*% target_cov %*% t(L)
  mod_cov0_delt <- L %*% mod_cov1 %*% t(L)
  mod_cov1_delt <- L %*% mod_cov2 %*% t(L)
  
  mod_mean0_new <- (L %*% mod_mean1)
  mod_mean1_new <- (L %*% mod_mean2)
  target_mean_new <- (L %*% target_mean)
  
  target_cov_inv <- solve(target_cov_delt)
  cov1_inv <- solve(mod_cov0_delt)
  cov2_inv <- solve(mod_cov1_delt)
  
  pr_a <- pr_a
  pr_b <- 1 - pr_a
  
  f.polar.partial <- roots.polar(cov1 = mod_cov0_delt, cov2 = mod_cov1_delt, cov1_inv = cov1_inv, cov2_inv = cov2_inv, mean1 = mod_mean0_new, mean2 = mod_mean1_new, pr_1 = pr_a, pr_2 = pr_b)
  
  g <- function(x) {
    theta <- x[1]
    gamma <- x[2]
    result <- f.polar.partial(theta, gamma)
    
    idx <- sign(result[c(3,4)]) > 0 &
      !is.infinite(result[c(3,4)]) &
      !is.nan(result[c(3,4)])
    
    val <- min(result[idx])
    
    if(val < 0) {
      val <- Inf
    }
    
    if(is.nan(val)) {
      val <- Inf
    }
    return(val)
  }

  r          <- sqrt(sum(mod_mean1_new^2))
  theta      <- acos(mod_mean1_new[3]/r)
  gamma      <- atan(mod_mean1_new[2]/mod_mean1_new[1])
  start.root <- f.polar.partial(theta, gamma)

  delta.start <- c(min(abs(vals[,1] - start.root[1])), min(abs(vals[,2] - start.root[2])))
  
  vals <- rbind(vals, c(start.root[1], start.root[2], delta.start))
  
  n.rows <- nrow(vals)
  roots <- lapply(1:n.rows, FUN = function(x) {f.polar.partial(vals[x,1], vals[x,2])})
  roots <- do.call(rbind, roots)
  
  coord <- roots[, c(1,2)]
  radius <- roots[, c(3,4)]
  
  idx.1 <- (sign(radius[,1]) > 0 & !is.infinite(radius[,1]) & 
              !is.na(radius[,1])) | (sign(radius[,2]) > 0 & !is.infinite(radius[,2]) & 
                                       !is.na(radius[,2]))
  
  idx.2 <- (sign(radius[,1]) > 0 & !is.infinite(radius[,1]) & 
              !is.na(radius[,1])) & (sign(radius[,2]) > 0 & !is.infinite(radius[,2]) & 
                                       !is.na(radius[,2]))
  
  idx.1 <- idx.1 & !idx.2

  new.coord.1  <- matrix(coord[idx.1,], ncol = 2)
  new.coord.2  <- matrix(coord[idx.2,], ncol = 2)
  new.radius.1 <- radius[idx.1, ]
  new.radius.1 <- new.radius.1[which(!is.infinite(new.radius.1) & new.radius.1 > 0)]
  
  new.radius.2 <- matrix(radius[idx.2, ], ncol = 2)
  
  delta.1      <- matrix(vals[idx.1, c(3,4)], ncol = 2)
  delta.2      <- matrix(vals[idx.2, c(3,4)], ncol = 2)

  new.radius.1 <- Rmpfr::mpfr(new.radius.1, 64)
  new.radius.2 <- Rmpfr::mpfr(new.radius.2, 64)
  
  f.1 <- function(x) {(sqrt(2) * exp(-x^2/2) * x + sqrt(pi) * erfc(x/sqrt(2)))/(4 * pi^(3/2))}

  if(is_empty(new.radius.1)) {
    root.eval.1 <- 0
  } else {
    root.eval.1          <- f.1(new.radius.1) * sin(new.coord.1[,1]) * delta.1[,1] * delta.1[,2]
  }
  
  if(is_empty(new.radius.2)){
    root.eval.2 <- 0
  } else {
    root.eval.2 <- (f.1(new.radius.2[,1]) - f.1(new.radius.2[,2]))  * sin(new.coord.2[,1]) * delta.2[,1] * delta.2[,2]    
  }
  
  return.val <- sum(root.eval.1) + sum(root.eval.2)
  
  return(return.val)
}

