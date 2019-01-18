//
//  AppDelegate.swift
//  App
//
//  Created by 津森智己 on 2018/08/08.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit
import CoreBluetooth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    /* ViewController間で受け渡しが必要な変数一覧 */
    
    /* Bluetooth関連 */
    
    var isScanning = false
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var myservice: CBService!
    var settingCharacteristic: CBCharacteristic!
    var outputCharacteristic: CBCharacteristic!
    
    // 発見したペリフェラルを格納するための配列
    var discoveredDevice: [CBPeripheral] = []
    
    let peripheralDeviceName = "BLE_DEVICE"
    // MLDPのUUID
    let mldpService_UUID = CBUUID(string: "00035B03-58E6-07DD-021A-08123A000300")
    // notify-write用UUID
    let mldpCharacteristic_UUID1 = CBUUID(string: "00035B03-58E6-07DD-021A-08123A000301")
    // read-write用UUID
    let mldpCharacteristic_UUID2 = CBUUID(string: "00035B03-58E6-07DD-021A-08123A0003FF")
    
    /* その他 */
    
    // Busy画面表示用変数
    var indicator = BusyIndicator.sharedManager
    // 接続待ちタイマー
    var connectTimer = Timer()
    // 切断状況判定変数
    var disconnectStatus = 0

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
}

