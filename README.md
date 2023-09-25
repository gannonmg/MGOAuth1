# MGOAuth1

## What is MGOAuth1?
A lightweight OAuth1 package for SwiftUI and using async/await.

Use this library to connect your users to services using the OAuth 1.0 standard for authorization. Simply initialize an `OAuthManager` with the `OAuthConfiguration` structure, which stores all the standard keys and URLs gathered from the service. 

## Installation
MGOAuth1 is available via `Swift Package Manager`. 

### To install:
1. Open your XCode project.
2. Click file at the top of your screen.
3. The second option down should be "Add Packages...".
4. In the window that appears, search for either `MGOAuth1` or `https://github.com/gannonmg/MGOAuth1`.
5. Select "Up to Next Major Version" and set the minimum to "1.0.2".
6. Click "Add Package" at the bottom right of the screen.
7. In the popup that appears, make sure the box next to MGOauth1 is selected.
8. Click "Add Package" once more, and the package should be good to go!

## Usage
### 1. OAuthConfiguration
1. Create a new file and add `import MGOAuth1` to the top of it.
2. Create an instance of an `OAuthConfiguration` struct using the information provided to you by the service. For example, here is what it looks like when setting up access for `Discogs`.

```swift
import MGOAuth1

let config: OAuthConfiguration = .init(
    client: "YourOAuthClient",
    consumerKey: "abcxxxxxxxxxxxxxxx123",
    consumerSecret: "xyzxxxxxxxxxxxxx789",
    callback: "your_oauth_app://oauth-callback/discogs",
    callbackScheme: "your_oauth_app",
    requestTokenUrl: "https://api.discogs.com/oauth/request_token",
    authorizeUrl: "https://www.discogs.com/oauth/authorize",
    accessTokenUrl: "https://api.discogs.com/oauth/access_token"
)
```
3. It is recommended not to commit this file to ensure the keys remain secure.

### 2. OAuthObservable
1. In a high level view in your app, create an `OAuthObservable` object using the configuration set up in the last step. This object can be passed along as an `ObservableObject` or `EnvironmentObject` as needed.
2. Add the `.oAuthSheet(oAuthObservable: OAuthObservable)` modifier to your view.
3. Add a login button that calls `OAuthObservable.authorize()`
4. `OAuthObservable` should handle the rest! It will pop a sheet, authorize your user, and store their access credentials for your app to use.

```swift
import MGOAuth1

struct ContentView: View {
    @StateObject var oauthObsv: OAuthObservable = .init(config: config)

    var body: some View {
        VStack {
            if oAuthObservable.isLoggedIn {
                Text("Pretty easy, right?")
            } else {
                Button("Authorize") {
                    oAuthObservable.authorize()
                }
            }
        }
        .oAuthSheet(oAuthObservable: oAuthObservable)
    }
}
```

In just a few lines of code, you now have an authorized user via OAuth!

To make an authorized request, simply call your target like so:

```swift
let user: User = try await oAuthObservable.manager.get(from: "https://api.discogs.com/oauth/identity")
```

At the moment, only `get` requests are supported. I do plan on updating to include more HTTP Methods, however, it is low on my priorities. It should be a fairly simple add, so if anyone would like to fork the repository and submit a pull request, be my guest!