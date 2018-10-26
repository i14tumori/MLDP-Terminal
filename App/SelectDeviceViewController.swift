//
//  SelectDeviceViewController.swift
//  App
//
//  Created by 津森智己 on 2018/08/08.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit
import CoreBluetooth

class SelectDeviceViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableview: UITableView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    let userDefaults = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        appDelegate.centralManager.scanForPeripherals(withServices: [appDelegate.mldpService_UUID], options: nil)
        
        // centralManagerのデリゲートをセット
        appDelegate.centralManager.delegate = self
        
        print("DeviceName : \(String(describing: self.userDefaults.string(forKey: "DeviceName")))")
        
        let controller: UIViewController = self
        // Indicator表示開始
        BusyIndicator.sharedManager.show(controller: controller)
        DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.milliseconds(1000)) {
            // Indicator表示終了
            BusyIndicator.sharedManager.dismiss()
            print("--- indicator ---")
            // 以前接続したペリフェラルの名前が存在するとき
            if let deviceName = self.userDefaults.string(forKey: "DeviceName") {
                // 発見されたペリフェラルの個数
                let deviceCount = self.appDelegate.discoveredDevice.count
                print("deviceCount : \(deviceCount)")
                for i in 0..<deviceCount {
                    print("i : \(i)")
                    // 以前接続したペリフェラルが検出されたとき
                    if deviceName == self.appDelegate.discoveredDevice[i].name {
                        // ペリフェラルを登録する
                        self.appDelegate.peripheral = self.appDelegate.discoveredDevice[i]
                        // 接続を開始する
                        self.connect()
                        // デバイス配列をクリアし元の画面に戻る
                        self.appDelegate.discoveredDevice = []
                        self.dismiss(animated: true, completion: nil)
                        break
                    }
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
     /* Bluetooth以外関連メソッド */
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("discoveredDevice Count:\(appDelegate.discoveredDevice.count)")
        return appDelegate.discoveredDevice.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableview.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        
        print("discoveredDevice Name:\(String(describing: appDelegate.discoveredDevice[indexPath.row].name!))")
        
        cell.textLabel!.text = appDelegate.discoveredDevice[indexPath.row].name
        return cell
    }
    
    func reload() {
        tableview?.reloadData()
    }
    
    // デバイスが選択されたとき
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // ペリフェラルを登録する
        appDelegate.peripheral = appDelegate.discoveredDevice[indexPath.row]
        
        // ペリフェラルを記憶する
        userDefaults.set(appDelegate.peripheral.name!, forKey: "DeviceName")
        userDefaults.synchronize()
        // 接続を開始する
        connect()
        // デバイス配列をクリアし元の画面に戻る
        appDelegate.discoveredDevice = []
        self.dismiss(animated: true, completion: nil)
    }
    
    // 接続を開始する関数
    func connect() {
        // 省電力のために探索停止
        appDelegate.centralManager?.stopScan()
        // 接続開始
        print("\(String(describing: appDelegate.peripheral.name!))へ接続開始")
        appDelegate.centralManager.connect(appDelegate.peripheral, options: nil)
    }
    
    // デバイス配列をクリアした後再読み込みしたいけど
    // 通知がもう一度来るわけではないのでTableViewが空欄になって終わる
    @IBAction func reloadButtonTapped(_ sender: UIButton) {
        // デバイス配列をクリア
        appDelegate.discoveredDevice = []
        reload()
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        // デバイス配列をクリアし元の画面に戻る
        appDelegate.discoveredDevice = []
        self.dismiss(animated: true, completion: nil)
    }
    
    /* Central関連メソッド */
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("CentralManagerState: \(central.state)")
        switch central.state {
        case .poweredOff:
            print("Bluetoothの電源がOff")
        case .poweredOn:
            print("Bluetoothの電源はOn")
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
        // デバイス配列に追加格納
        appDelegate.discoveredDevice.append(peripheral)
        reload()
    }
}
