# MyFridge
MyFridge is an iPhone app that tracks what's in your fridge by expiration date. Groceries are entered into the app via a picture of the receipt, manually, or by screenshot. The parsing and intelligence run directly on your iPhone using Apple's Vision and Foundation Models frameworks, but this does not work on iPhone's older than the 15. For iPhones older than the 15, MyFridge will use a non-AI parsing which is very untested. 

## Features 
- Receipt scanning
- Screenshot imports
- Apple Intelligence AI parsing
- Automatic expiry dates from USDA FoodKeeper
- Learns from past expiration corrections
- Weight tracking for meat, poultry, and seafood
- Notifications for expiring food

## Technologies

| Area              | Technology                           |
| ----------------- | ------------------------------------ |
| Languages         | Swift6                               |
| UI                | SwiftUI                              |
| Persistence       | SwiftData                            |
| Intelligence      | Apple Intelligence Foundation Models |

## Requirements
- Xcode 26
- iOS 26.0 
- iPhone 15 or higher

## Privacy
All processing happens on the device, the app makes no network requests and collects no data. 
