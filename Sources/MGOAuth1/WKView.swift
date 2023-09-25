//
//  WebView.swift
//  MGOAuth
//
//  Created by Matt Gannon on 8/3/22.
//

import SwiftUI
import WebKit

public struct WKView: UIViewRepresentable {
    
    @EnvironmentObject var viewModel: OAuthObservable
    @Binding var url: URL?
    
    public typealias UIViewType = WKWebView
    
    public init(url: Binding<URL?>) {
        _url = url
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let webView: WKWebView = .init(frame: .zero)
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = url else { return }
        let request: URLRequest = .init(url: url)
        uiView.load(request)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WKView

        init(_ parent: WKView) {
            self.parent = parent
        }
        
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            #warning("replace with callback from config")
            print("WebView url: ", webView.url?.absoluteString ?? "no url?")
            if let url = webView.url, url.absoluteString.contains("vinyl_space://oauth-callback") {
                try? parent.viewModel.onOAuthRedirect(url)
            }
            
            decisionHandler(.allow)
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

public extension View {
    func oauthSheet(oAuthObservable: OAuthObservable) -> some View {
        self.modifier(OAuthSheetModifier(oAuthObservable: oAuthObservable))
    }
}

struct OAuthSheetModifier: ViewModifier {
    @ObservedObject var oAuthObservable: OAuthObservable

    func body(content: Content) -> some View {
        content.sheet(isPresented: $oAuthObservable.authorizationSheetIsPresented) {
            NavigationView {
                WKView(url: $oAuthObservable.authorizationURL)
                    .environmentObject(oAuthObservable)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {}
                        }
                    }
            }
        }
    }
}
