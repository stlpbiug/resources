// Use this file to write queries to test your data connector
let
    result = YNAB.Contents("https://api.youneedabudget.com/v1/budgets/")
in
    result