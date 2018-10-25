//
//  BLEController.swift
//  App
//
//  Created by 津森智己 on 2018/10/25.
//  Copyright © 2018 津森智己. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class BLEControll: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let userDefaults = UserDefaults.standard
    
    func delegateSet() {
        // インスタンスの生成および初期化
        appDelegate.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        print("delegateSet : \(String(describing: appDelegate.centralManager.delegate))")
    }
    
    func scan() {
        appDelegate.centralManager.scanForPeripherals(withServices: [appDelegate.mldpService_UUID], options: nil)
    }
    
    func disconnect() {
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            appDelegate.showToast(message: "デバイス未接続", classView: ViewController().view)
            return
        }
        
        appDelegate.peripheral.setNotifyValue(false, for: appDelegate.outputCharacteristic)
        appDelegate.centralManager.cancelPeripheralConnection(appDelegate.peripheral)
    }
    
    /* Central関連メソッド */
    
    // centralManagerの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("--- centralManagerDidUpdateState ---")
        switch central.state {
        case .poweredOff:
            print("Bluetooth電源 : OFF")
            appDelegate.showToast(message: "Bluetoothの電源がOFF", classView: ViewController().view)
        case .poweredOn:
            print("Bluetooth電源 : ON")
        case .resetting:
            print("レスティング状態")
        case .unauthorized:
            print("非認証状態")
        case .unknown:
            print("不明")
        case .unsupported:
            print("非対応")
        }
    }
    
    // ペリフェラルを発見したときに呼ばれる
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // ??? 繋がらない
        print("記憶したデバイス名 : \(String(describing: userDefaults.string(forKey: "DeviceName")))")
        /*
         if userDefaults.string(forKey: "DeviceName") == peripheral.name! {
         // ペリフェラルを登録する
         appDelegate.peripheral = peripheral
         // 省電力のために探索停止
         appDelegate.centralManager?.stopScan()
         
         // 接続開始
         print("\(String(describing: appDelegate.peripheral.name!))へ接続開始")
         appDelegate.centralManager.connect(appDelegate.peripheral, options: nil)
         
         // デバイス配列をクリアし元の画面に戻る
         appDelegate.discoveredDevice = []
         self.dismiss(animated: true, completion: nil)
         return
         }
         */
        // デバイス配列に追加格納
        appDelegate.discoveredDevice.append(peripheral)
        SelectDeviceViewController().reload()
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("接続成功")
        print("接続デバイス:\(appDelegate.peripheral.name!)")
        appDelegate.centralManager.stopScan()
        print("探索終了")
        
        // サービス探索結果を受け取るためにデリゲートをセット
        appDelegate.peripheral.delegate = self
        
        // サービス探索開始
        appDelegate.peripheral.discoverServices([appDelegate.mldpService_UUID])
    }
    
    /* Peripheral関連メソッド */
    
    // サービスを発見すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // エラーのときは原因を出力してreturn
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        // 代入されたservicesがnilまたはカウントが0のときにguard文内へ進む
        guard let services = peripheral.services, services.count > 0 else {
            print("no services")
            return
        }
        
        print("\(services.count)個のサービスを検出 \(services)")
        // サービスの数だけキャラクタリスティック探索
        for service in services {
            // キャラクタリスティック探索開始
            appDelegate.peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // キャラクタリスティックを発見すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print(error.debugDescription)
            return
        }
        
        // 代入されたcharacteristicsがnilまたはカウントが0の時にguard文内へ進む
        guard let characteristics = service.characteristics, characteristics.count > 0 else {
            print("no characteristics")
            return
        }
        
        print("\(characteristics.count)個のキャラクタリスティックを検出 \(characteristics)")
        
        // whereを満たす間characteristicsからcharacteristicへ一つずつ取り出す
        // 複数個あってもMLDPのキャラクタリスティックにのみ反応するようにしている
        for characteristic in characteristics where characteristic.uuid.isEqual(appDelegate.mldpCharacteristic_UUID1) {
            appDelegate.outputCharacteristic = characteristic
            print("Write Indicate UUID を発見")
            // characteristicの値を読み取る
            peripheral.readValue(for: characteristic)
            
            // 更新通知受け取りを開始する
            peripheral.setNotifyValue(true, for: characteristic)
            
            // 書き込みデータの準備(文字を文字コードに変換?)
            let str = "App:on\r\n"
            let data = str.data(using: String.Encoding.utf8)
            
            // ペリフェラルにデータを書き込む
            peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
            
            appDelegate.showToast(message: "デバイス接続", classView: ViewController().view)
        }
    }
    
    // Notify開始/停止時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error.debugDescription)
        } else {
            print("Notify状態更新 characteristic UUID : \(characteristic.uuid), isNotifying : \(characteristic.isNotifying)")
        }
    }
    
    // データ更新時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error.debugDescription)
            return
        }
        ViewController().dataUpdate(peripheral, didUpdateValueFor: characteristic)
    }
}
