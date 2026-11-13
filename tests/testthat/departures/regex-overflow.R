# Matcher for the departure `regex-overflow`: R raised the package's error
# for a regex that overflowed the backtracking limit, whatever the
# reference gives.
function(difference) {
  inherits(difference$actual, "ftfy_regex_overflow")
}
