//
//  ViewController.swift
//  App
//
//  Created by 津森智己 on 2018/08/08.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate {
       
    var response = ""

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var textview: UITextView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        textfield.delegate = self
        
        // テキストのフォント設定
        textfield.font = UIFont(name: "CourierNewPSMT", size: textfield.font!.pointSize)
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // TextViewを編集できないようにする
        textview.isEditable = false
        
        // インスタンスの生成および初期化
        appDelegate.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        print("centralManagerDelegate set")
        appDelegate.centralManager.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /* Bluetooth以外関連メソッド */
    
    // タッチ開始時のタッチイベント
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touches began")
        // キーボードを閉じる
        self.view.endEditing(true)
    }
    
    // textfieldの値が変更される度に呼び出される
    // 第一引数:変更前文字列，第二引数:変更される文字列のインデックス範囲
    // 第三引数:新しい文字列
    // trueを返すと入力確定，falseを返すと入力確定を拒否
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 入力文字数の最大値
        let maxLength: Int = 18
        // 入力済み文字と入力された文字を合わせて取得
        let str = textField.text! + string
        // 文字数がmaxLength以下ならtrue
        if str.characters.count < maxLength {
            return true
        }
        print("最大文字数超過")
        return false
    }
    
    // textField入力でreturn(改行)が押されたとき
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textfield should return")
        // キーボードを閉じる
        textField.endEditing(true)
        
        return true
    }
    
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        print("send button tapped")
        // キーボードを閉じる
        textfield.endEditing(true)
        
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            return
        }
        
        // 書き込みデータの準備(文字を文字コードに変換?)
        var str = textfield.text!
        str = str + "\r\n"
        let data = str.data(using: String.Encoding.utf8)
        
        // ペリフェラルにデータを書き込む
        appDelegate.peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
        
        // texiFieldのクリア
        textfield.text = ""
    }
    
    @IBAction func clearButtonTapped(_ sender: UIButton) {
        print("clear button tapped")
        textview.text = ""
        textfield.text = ""
    }
    
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        print("scan button tapped")
        appDelegate.centralManager.scanForPeripherals(withServices: [appDelegate.mldpService_UUID], options: nil)
    }
    
    @IBAction func disconButtonTapped(_ sender: UIButton) {
        print("disconnect button tapped")
        appDelegate.peripheral.setNotifyValue(false, for: appDelegate.outputCharacteristic)
        appDelegate.centralManager.cancelPeripheralConnection(appDelegate.peripheral)
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
        
        //  読み込みデータの取り出し(文字コードを文字に変換?)
        let data = characteristic.value
        let dataString = String(data: data!, encoding: String.Encoding.utf8)
        
        // textViewに読み込みデータを書き込む
        textview.text = textview.text! + dataString!
    }
    
}

