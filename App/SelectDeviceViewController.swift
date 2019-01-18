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
        
        print("--- viewWillAppear ---")
        print("centralManager : \(String(describing: appDelegate.centralManager))")
        
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
                for i in 0..<deviceCount {
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
        
        // Notificationを設定する
        configureObserver()
    }
    
    // viewが消える前のイベント
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        // Notificationを削除する
        removeObserver()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // textview移動のNotificationを設定する関数
    func configureObserver() {
        let notification = NotificationCenter.default
        // 画面回転の検知
        notification.addObserver(self, selector: #selector(onOrientationChange(notification:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    // textview移動のNotificationを削除する関数
    func removeObserver() {
        let notification = NotificationCenter.default
        notification.removeObserver(self)
    }
    
    // 画面が回転したときに呼ばれる関数
    @objc func onOrientationChange(notification: Notification?) {
        // indicatorを表示しているとき
        if appDelegate.indicator.isShow {
            // 再表示
            appDelegate.indicator.show(controller: self)
        }
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
        
        // タイマーがすでに動作しているとき
        if appDelegate.connectTimer.isValid {
            // 現在のタイマーを破棄する
            appDelegate.connectTimer.invalidate()
        }
        // タイマーを生成する
        appDelegate.connectTimer = Timer.scheduledTimer(timeInterval: 5, target: ViewController(), selector: #selector(ViewController().timeOut), userInfo: nil, repeats: false)
        print("waiting for connection")
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
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
        case .poweredOn:
            print("Bluetoothの電源はOn")
            // Indicator表示終了
            appDelegate.indicator.dismiss()
        case .resetting:
            print("レスティング状態")
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
        case .unauthorized:
            print("非認証状態")
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
        case .unknown:
            print("不明")
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
        case .unsupported:
            print("非対応")
            // Indicator表示開始
            appDelegate.indicator.show(controller: self)
        }
    }
    
    // ペリフェラルを発見したときに呼ばれる
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // デバイス配列に追加格納
        appDelegate.discoveredDevice.append(peripheral)
        reload()
    }
}
