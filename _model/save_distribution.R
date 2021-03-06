#' Compute mean vector and covariance matrices for all conditions in the experiment.
save_gaussian_distributions <- function(template_response) {
  library(dplyr)
  library(parallel)
  library(tidyr)
  library(mvtnorm)

  template_response <- 
    template_response %>% select(-one_of("L","C","S", "statType", "statValue"))
  
  summarize <- dplyr::summarise
  
  f <- function(x) {
    model_statistics <- template_response %>%
      unique() %>%
      filter(eccentricity == x) %>%
      dplyr::select(eccentricity,
                    BIN,
                    function_name,
                    SAMPLE,
                    TARGET,
                    TPRESENT,
                    TRESP) %>%
      mutate(TARGET = factor(
        TARGET,
        levels = c("vertical", "horizontal", "bowtie", "spot")
      )) %>%
      arrange(SAMPLE, TARGET, BIN, eccentricity, TPRESENT, function_name) %>%
      group_by(BIN, TARGET, eccentricity, function_name, TPRESENT) %>%
      spread(function_name, TRESP) %>%
      summarize(
        edge_mean = mean(edge_cos),
        pattern_mean = mean(pattern_only),
        edge_sd = sd(edge_cos),
        pattern_sd = sd(pattern_only),
        edge_pattern_cor = cor(edge_cos, pattern_only),
        cor_mat = list(cor(as.matrix(
          data.frame(edge_cos, pattern_only)
        ))),
        cov_mat = list(cov(as.matrix(
          data.frame(edge_cos, pattern_only)
        ))),
        inv_cov_mat = list(solve(cov_mat[[1]]))
      ) %>%
      rowwise() %>%
      mutate(
        mean_vec = list(c(edge_mean, pattern_mean)),
        sd_vec   = list(sqrt(diag(cov_mat))),
        var_vec  = list(diag(cov_mat)),
        cor_vec  = list(cor_mat[upper.tri(cor_mat)]),
        cov_vec  = list(cov_mat[upper.tri(cor_mat)])
      ) %>%
      arrange(BIN, TARGET, TPRESENT, eccentricity) %>%
      mutate(TARGET = factor(TARGET)) %>%
      dplyr::select(
        BIN,
        TARGET,
        eccentricity,
        TPRESENT,
        cor_mat,
        cov_mat,
        inv_cov_mat,
        sd_vec,
        mean_vec,
        sd_vec,
        var_vec,
        cor_vec,
        cov_vec
      )
  }
  
  g <- function(x) {
    model_responses <- template_response %>%
      unique() %>%
      filter(eccentricity == x) %>%
      select(eccentricity,
             BIN,
             function_name,
             SAMPLE,
             TARGET,
             TPRESENT,
             TRESP,
             PATCHID) %>%
      spread(function_name, TRESP) %>%
      mutate(TARGET = factor(
        TARGET,
        levels = c("vertical", "horizontal", "bowtie", "spot")
      )) %>%
      group_by(BIN, TARGET, eccentricity, TPRESENT) %>%
      summarize(PATCHID = list(PATCHID),
                response_vec = list(as.matrix(
                  data.frame(
                    edge = edge_cos,
                    pattern = pattern_only
                  )
                ))) %>%
      select(BIN, TARGET, eccentricity, TPRESENT, response_vec, PATCHID)
  }
  
  model.data.all <-
    mclapply(
      unique(template_response$eccentricity),
      FUN =
        function(x) {
          model.stats <- f(x)
          
          model.responses <- g(x)
          
          model.stats$response_vec <-
            model.responses$response_vec
          
          model.stats$PATCHID <- 
            model.responses$PATCHID
          
          model.data <- model.stats %>%
            arrange(TARGET, eccentricity, BIN, TPRESENT) %>%
            mutate(TPRESENT = ifelse(TPRESENT == "absent", 0, 1))
          
          save(
            file = paste0(
              "~/Dropbox/Calen/Work/occluding/occlusion_detect/_data/_model_response/model_distribution_",
              as.character(floor(x)),
              ".rdata"
            ),
            model.data
          )
          return(model.data)
        },
      mc.cores = 16
    )
  
  model.data.all <- do.call(rbind, model.data.all)
  
  model.wide <- model.data.all %>%
    gather(mat_type, value,-(BIN:TPRESENT)) %>%
    unite(data, mat_type, TPRESENT) %>%
    spread(data, value, sep = '_')
  
  save(
    file = paste0(
      "~/Dropbox/Calen/Work/occluding/occlusion_detect/_data/_model_response/model_distribution_all.rdata"
    ),
    model.data.all
  )
  save(
    file = paste0(
      "~/Dropbox/Calen/Work/occluding/occlusion_detect/_data/_model_response/model_wide.rdata"
    ),
    model.wide
  )
  
  return(model.wide)
}

