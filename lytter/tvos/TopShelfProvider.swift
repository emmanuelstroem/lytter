//
//  TopShelfProvider.swift
//  lytter (tvOS)
//
//  NOTE: This class implements a TV Top Shelf content provider. To activate it,
//  create a tvOS Top Shelf Extension target with NSExtensionPointIdentifier
//  "com.apple.tv-top-shelf" and set NSExtensionPrincipalClass to
//  "$(PRODUCT_MODULE_NAME).TopShelfProvider". The logic below will then provide
//  a sectioned Top Shelf consistent with Apple's HIG.
//

// Placeholder file for the Top Shelf provider implementation.
// To enable Top Shelf per Apple's HIG (see: https://developer.apple.com/design/human-interface-guidelines/top-shelf),
// create a separate Top Shelf extension target and include a provider that returns
// a sectioned set of items (one item for each channel). For channels like P4 and P5,
// select a single representative district (e.g., København) to avoid duplicates on the shelf.
//
// This file intentionally contains no compiled code in the app target to keep builds green
// until the extension target is added.
//
// Steps in Xcode:
// 1) File > New > Target… > tvOS > Top Shelf Extension.
// 2) In the new target, add a provider class (e.g., TopShelfProvider) that fetches channels
//    and constructs TVTopShelfSectionedContent with TVTopShelfItem entries.
// 3) Set NSExtensionPrincipalClass and extension point identifier in the extension Info.plist.

