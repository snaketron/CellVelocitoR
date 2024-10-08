#' Model-based quantification of cell velocity
#'
#' The functions takes a data.frame, x, as its main input. Meanwhile,
#' the input list control can be used to configure the MCMC procedure
#' performed by R-package rstan.  The output is a list which contains:
#' 1) f = fit as rstan object; 2) x = processed input; 3) s = summary
#' of model parameters (means, medians, 95% credible intervals, etc.).
#'
#' The input x must have cell entries as rows and the following columns:
#' * replicate = id of the biological replicate (e.g. rep1, rep2, rep3, ...)
#' * batch = id of the experimental batch (e.g. plate X, plat Y, ...)
#' * compound = character id of the treatment compound
#' * dose = numeric
#' * v = numeric cell speed
#'
#' @return a list
#' @export
#' @examples
#' data(d, package = "cellvel")
#' o <- cellvel(x = d,
#'              control = list(mcmc_warmup = 300,
#'                             mcmc_steps = 600,
#'                             mcmc_chains = 3,
#'                             mcmc_cores = 1,
#'                             mcmc_algorithm = "NUTS",
#'                             adapt_delta = 0.9,
#'                             max_treedepth = 10))
#' head(o)
cellvel <- function(x, control = NULL, model) {

  # check inputs
  x <- process_input(x)

  # check control
  control <- process_control(control_in = control)

  # fit model
  f <- get_fit(x = x, control = control, model = model)

  # get summary
  s <- get_summary(x = x, f = f)

  return(list(f = f, x = x, s = s))
}


get_fit <- function(x, control, model) {
  message("model fitting... \n")

  # transform data
  q <- x[, c("s", "g", "r", "b")]
  q <- q[duplicated(q)==F, ]
  q <- q[order(q$s, decreasing = F),]

  if(model == "M") {
    M <- stanmodels$M
  }
  if(model == "Mp") {
    M <- stanmodels$Mp
  }
  if(model == "Ms") {
    M <- stanmodels$Ms
  }
  if(model == "Ms_pro") {
    M <- stanmodels$Ms_pro
  }

  # fit model
  fit <- sampling(object = M,
                  data = list(y = x$sv, N = nrow(x), s = x$s,
                              g = q$g, r = q$r, b = q$b),
                  chains = control$mcmc_chains,
                  cores = control$mcmc_cores,
                  iter = control$mcmc_steps,
                  warmup = control$mcmc_warmup,
                  algorithm = control$mcmc_algorithm,
                  control = list(adapt_delta = control$adapt_delta,
                                 max_treedepth = control$max_treedepth),
                  refresh = 100)

  return(fit)
}


get_summary <- function(x, f) {
  message("computing posterior summaries...\n")

  # get unique meta data
  l <- x[, c("s", "sample", "g", "group", "treatment", "dose",
             "r", "replicate", "b", "batch")]
  l_s <- l[duplicated(l)==FALSE, ]
  l_r <- l[duplicated(l[,c("r","replicate")])==FALSE,
           c("r","replicate")]
  l_p <- l[duplicated(l[,c("b","batch")])==FALSE,
           c("b","batch")]
  l_g <- l[duplicated(l[,c("g","group")])==FALSE,
           c("g","group", "treatment", "dose",
             "r","replicate","b","batch")]

  # par: eff_rep
  eff_rep <- data.frame(summary(f, par = "eff_rep")$summary)
  eff_rep$r <- 1:nrow(eff_rep)
  eff_rep <- merge(x = eff_rep, y = l_r, by = "r", all.x = TRUE)

  # par: eff_batch
  eff_batch <- data.frame(summary(f, par = "eff_batch")$summary)
  eff_batch$b <- 1:nrow(eff_batch)
  eff_batch <- merge(x = eff_batch, y = l_p, by = "b", all.x = TRUE)

  # par: eff_group_mu
  eff_group_mu <- data.frame(summary(f, par = "eff_group_mu")$summary)
  eff_group_mu$g <- 1:nrow(eff_group_mu)
  eff_group_mu <- merge(x = eff_group_mu, y = l_g, by = "g", all.x = TRUE)

  # par: eff_sample
  eff_sample <- data.frame(summary(f, par = "eff_sample")$summary)
  eff_sample$s <- 1:nrow(eff_sample)
  eff_sample <- merge(x = eff_sample, y = l_s, by = "s", all.x = TRUE)

  # par: eff_group_sigma
  eff_group_sigma <- data.frame(summary(f, par = "eff_group_sigma")$summary)

  # par: mu
  mu <- data.frame(summary(f, par = "mu")$summary)
  mu$s <- 1:nrow(mu)
  mu <- merge(x = mu, y = l_s, by = "s", all.x = TRUE)

  # par: y_hat_sample
  yhat <- data.frame(summary(f, par = "y_hat_sample")$summary)
  yhat$s <- 1:nrow(yhat)
  yhat <- merge(x = yhat, y = l_s, by = "s", all.x = TRUE)

  return(list(eff_rep = eff_rep, eff_batch = eff_batch,
              eff_group_mu = eff_group_mu, eff_sample = eff_sample,
              eff_group_sigma = eff_group_sigma, mu = mu, yhat = yhat))
}

