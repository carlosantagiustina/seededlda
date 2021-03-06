#' Semisupervised Latent Dirichlet allocation
#'
#' `textmodel_seededlda()` implements semisupervised Latent Dirichlet allocation (seeded-LDA).
#' The estimator's code adopted from the GibbsLDA++ library (Xuan-Hieu Phan,
#' 2007). `textmodel_seededlda()` allows identification of pre-defined topics by
#' semisupervised learning with a seed word dictionary.
#' @param dictionary a [quanteda::dictionary()] with seed words as
#'  examples of topics.
#' @param residual if \code{TRUE} a residual topic (or "garbage topic") will be
#'   added to user-defined topics.
#' @param weight pseudo count given to seed words as a proportion of total
#'   number of words in `x`.
#' @param valuetype see [quanteda::valuetype]
#' @param case_insensitive see [quanteda::valuetype]
#' @references
#'   Lu, Bin et al. (2011).
#'   [Multi-aspect Sentiment Analysis with Topic Models](https://dl.acm.org/doi/10.5555/2117693.2119585).
#'   *Proceedings of the 2011 IEEE 11th International Conference on Data Mining Workshops*.
#'
#'   Watanabe, Kohei & Zhou, Yuan (2020).
#'   [Theory-Driven Analysis of Large Corpora: Semisupervised Topic Classification of the UN Speeches](https://doi.org/10.1177/0894439320907027).
#'   *Social Science Computer Review*.
#'
#' @examples
#' \dontrun{
#' require(quanteda)
#'
#' data("data_corpus_moviereviews", package = "quanteda.textmodels")
#' corp <- head(data_corpus_moviereviews, 500)
#' dfmt <- dfm(corp, remove_number = TRUE) %>%
#'     dfm_remove(stopwords('en'), min_nchar = 2) %>%
#'     dfm_trim(min_termfreq = 0.90, termfreq_type = "quantile",
#'              max_docfreq = 0.1, docfreq_type = "prop")
#'
#' # unsupervised LDA
#' lda <- textmodel_lda(dfmt, 6)
#' terms(lda)
#'
#' # semisupervised LDA
#' dict <- dictionary(list(people = c("family", "couple", "kids"),
#'                         space = c("areans", "planet", "space"),
#'                         moster = c("monster*", "ghost*", "zombie*"),
#'                         war = c("war", "soldier*", "tanks"),
#'                         crime = c("crime*", "murder", "killer")))
#' slda <- textmodel_seededlda(dfmt, dict, residual = TRUE)
#' terms(slda)
#' }
#' @export
textmodel_seededlda <- function(
    x, dictionary,
    valuetype = c("glob", "regex", "fixed"),
    case_insensitive = TRUE,
    residual = FALSE, weight = 0.01,
    max_iter = 2000, alpha = NULL, beta = NULL,
    verbose = quanteda_options("verbose")
) {
    UseMethod("textmodel_seededlda")
}

#' @export
textmodel_seededlda.dfm <- function(
    x, dictionary,
    valuetype = c("glob", "regex", "fixed"),
    case_insensitive = TRUE,
    residual = FALSE, weight = 0.01,
    max_iter = 2000, alpha = NULL, beta = NULL,
    verbose = quanteda_options("verbose")
) {

    seeds <- tfm(x, dictionary, weight = weight, residual = residual)
    if (!identical(colnames(x), rownames(seeds)))
        stop("seeds must have the same features")
    k <- ncol(seeds)
    label <- colnames(seeds)
    lda(x, k, label, max_iter, alpha, beta, seeds, verbose)
}

#' Print method for a LDA model
#' @param x for print method, the object to be printed
#' @param ... unused
#' @method print textmodel_lda
#' @keywords internal textmodel
#' @export
print.textmodel_lda <- function(x, ...) {
    cat("\nCall:\n")
    print(x$call)
    cat("\n",
        "Topics: ", x$k, "; ",
        ndoc(x$x), " documents; ",
        nfeat(x$x), " features.",
        "\n",
        sep = "")
}

#' Extract most likely terms
#' @param x a fitted LDA model
#' @param n number of terms to be extracted
#' @export
terms <- function(x, n = 10) {
    UseMethod("terms")
}
#' @export
#' @method terms textmodel_lda
#' @importFrom utils head
terms.textmodel_lda <- function(x, n = 10) {
    apply(x$phi, 1, function(x, y, z) head(y[order(x, decreasing = TRUE), drop = FALSE], z),
          colnames(x$phi), n)
}

#' Extract most likely topics
#' @export
#' @param x a fitted LDA model
topics <- function(x) {
    UseMethod("topics")
}
#' @export
#' @method topics textmodel_lda
topics.textmodel_lda <- function(x) {
    colnames(x$theta)[max.col(x$theta)]
}

#' Internal function to construct topic-feature matrix
#' @noRd
tfm <- function(x, dictionary,
                valuetype = c("glob", "regex", "fixed"),
                case_insensitive = TRUE,
                weight = 0.01, residual = TRUE) {

    valuetype <- match.arg(valuetype)

    if (!quanteda::is.dictionary(dictionary))
        stop("dictionary must be a dictionary object")
    if (weight < 0)
        stop("weight must be pisitive a value")

    id_key <- id_feat <- integer()
    for (i in seq_along(dictionary)) {
        f <- colnames(quanteda::dfm_select(x, dictionary[i]))
        id_key <- c(id_key, rep(i, length(f)))
        id_feat <- c(id_feat, match(f, colnames(x)))
    }
    count <- rep(floor(sum(x) * weight), length(id_feat))
    key <- names(dictionary)
    if (residual)
        key <- c(key, "other")
    result <- Matrix::sparseMatrix(
        i = id_feat,
        j = id_key,
        x = count,
        dims = c(nfeat(x), length(key)),
        dimnames = list(colnames(x), key)
    )
    return(result)
}
