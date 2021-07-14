section YNAB;

client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1200;
windowHeight = 1000;

[DataSource.Kind="YNAB", Publish="YNAB.UI"]
shared YNAB.Contents = Value.ReplaceType(YNABConnect.Contents, type function (url as Uri.Type) as any);

// Data Source Kind description
YNAB = [
    TestConnection = (dataSourcePath) => {"YNAB.Contents", dataSourcePath},
    Authentication = [    
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];


YNABConnect.Contents = (url as text) =>
    let
        source = Web.Contents(url),
        json = Json.Document(source)
    in
        json;


// Data Source UI publishing description
YNAB.UI = [
    Beta = true,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = YNAB.Icons,
    SourceTypeImage = YNAB.Icons
];

YNAB.Icons = [
    Icon16 = { Extension.Contents("YNAB16.png"), Extension.Contents("YNAB20.png"), Extension.Contents("YNAB24.png"), Extension.Contents("YNAB32.png") },
    Icon32 = { Extension.Contents("YNAB32.png"), Extension.Contents("YNAB40.png"), Extension.Contents("YNAB48.png"), Extension.Contents("YNAB64.png") }
];

//
// OAuth2 flow definition
//

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://app.youneedabudget.com/oauth/authorize?" & Uri.BuildQueryString([
            client_id = client_id,
            scope = "read-only",
            state = state,
            response_type = "code",
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id,
            grant_type=grantType,
            redirect_uri = redirect_uri,
            client_secret = client_secret
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),
        tokenResponse = Web.Contents("https://app.youneedabudget.com/oauth/token?", [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;
