//
//  ViewController.swift
//  App
//
//  Created by 津森智己 on 2018/08/08.
//  Copyright © 2018年 津森智己. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate, UITextViewDelegate {
       
    var response = ""
    let maxLength = 18

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var textview: UITextView!
    
    // AppDelegate内の変数呼び出し用
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        textfield.delegate = self
        textview.delegate = self
 
        // TextViewに枠線をつける
        textview.layer.borderColor = UIColor.gray.cgColor
        textview.layer.borderWidth = 0.5
        textview.layer.cornerRadius = 5
        
        // TextFieldの枠線をTextViewに揃える
        textfield.layer.borderColor = UIColor.gray.cgColor
        textfield.layer.borderWidth = 0.5
        textfield.layer.cornerRadius = 5
        
        // カーソル表示
        let stringAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.gray, .foregroundColor : UIColor.gray]
        let attrText = NSMutableAttributedString(string: "_", attributes: stringAttributes)
        textview.attributedText = attrText
        
        // テキストのフォント設定
        textfield.font = UIFont(name: "CourierNewPSMT", size: textfield.font!.pointSize)
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
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
   
    // textField入力でreturn(改行)が押されたとき
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textfield should return")
        // キーボードを閉じる
        textField.endEditing(true)
        
        return true
    }
    
    // textViewの入力値を取得し、最後尾に追記
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("replacementText : \(text)")
        var replacementText = text
        // バックスペースの場合(textには何も入っていない)
        if text.count == 0 {
            // バックスペースに置き換え
            replacementText = "\u{08}"
        }
        // 最後尾に追記
        writeTextView(replacementText)
        // カーソル位置への追記はしない
        return false
    }
    
    // sendButtonが押されたとき
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        print("send button tapped")
        // キーボードを閉じる
        textfield.endEditing(true)
        
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            showToast(message: "デバイス未接続")
            return
        }
        
        // 送信文字数の制限をなくす(本来は(改行コード抜きで)18文字)
        let txText = textfield.text!
        /* 商　quotient 余り　remainder */
        let remainder = txText.count % maxLength
        
        for i in stride(from: 0, to: txText.count - remainder, by: maxLength) {
            let splitText = txText[txText.index(txText.startIndex, offsetBy: i)..<txText.index(txText.startIndex, offsetBy: i + maxLength)]
            let data = splitText.data(using: String.Encoding.utf8)
            // ペリフェラルにデータを書き込む
            appDelegate.peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
        
        let splitText = String(txText.suffix(remainder)) + "\r\n"
        let data = splitText.data(using: String.Encoding.utf8)
        // ペリフェラルにデータを書き込む
        appDelegate.peripheral.writeValue(data!, for: appDelegate.outputCharacteristic, type: CBCharacteristicWriteType.withResponse)
        
        // texiFieldのクリア
        textfield.text = ""
    }
    
    // clearButtonが押されたとき
    @IBAction func clearButtonTapped(_ sender: UIButton) {
        print("clear button tapped")
        textfield.text = ""
        // カーソル表示
        let stringAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.gray]
        let attrText = NSMutableAttributedString(string: " ", attributes: stringAttributes)
        textview.attributedText = attrText
        
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textfield.font!.pointSize)
    }
    
    // scanButtonが押されたとき
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        print("scan button tapped")
        appDelegate.centralManager.scanForPeripherals(withServices: [appDelegate.mldpService_UUID], options: nil)
    }
    
    // disconButtonが押されたとき
    @IBAction func disconButtonTapped(_ sender: UIButton) {
        print("disconnect button tapped")
        
        if appDelegate.outputCharacteristic == nil {
            print("\(appDelegate.peripheralDeviceName) is not ready")
            showToast(message: "デバイス未接続")
            return
        }
        
        appDelegate.peripheral.setNotifyValue(false, for: appDelegate.outputCharacteristic)
        appDelegate.centralManager.cancelPeripheralConnection(appDelegate.peripheral)
        
        // 変数の初期化
        appDelegate.settingCharacteristic = nil
        appDelegate.outputCharacteristic = nil
        appDelegate.discoveredDevice = []
    }
    
    // トースト出力関数
    func showToast(message : String) {
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 150, y: self.view.frame.size.height/2, width: 300, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
    
    /* Central関連メソッド */
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("CentralManagerState: \(central.state)")
        switch central.state {
        case .poweredOff:
            print("Bluetoothの電源がOff")
            showToast(message: "Bluetoothの電源がOFF")
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
            
            showToast(message: "デバイス接続")
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
        
        textview.isScrollEnabled = false
        
        //  読み込みデータの取り出し(文字コードを文字に変換?)
        let data = characteristic.value
        let dataString = String(data: data!, encoding: String.Encoding.utf8)
        
        print("dataString:\(String(describing: dataString))")
        
        // textViewに読み込みデータを書き込む
        writeTextView(dataString!)
        
    }
    
    // textviewに文字を書き込む関数
    func writeTextView(_ string: String) {
        // 空白文字の背景をグレーにし、カーソル代わりにする
        let stringAttributes: [NSAttributedStringKey : Any] = [.backgroundColor : UIColor.gray, .foregroundColor : UIColor.gray]
        let attrText = NSMutableAttributedString(string: "_", attributes: stringAttributes)
        
        // カーソル用空白文字を取り除く
        var getText = textview.text!
        if getText.count != 0 {
            getText = String(getText.prefix(getText.count-1))
        }
        
        let plainText = NSMutableAttributedString(string: getText + string)
        
        // 文字列とカーソルの結合用定数
        let text = NSMutableAttributedString()
        
        // 文字列とカーソルを結合する
        text.append(plainText)
        text.append(attrText)
        
        // textviewに設定する
        textview.attributedText = text
        // フォントを再設定する
        textview.font = UIFont(name: "CourierNewPSMT", size: textview.font!.pointSize)
        
        // 画面のスクロール
        scrollToButtom()
    }
    
    // textviewを最下までスクロールする関数
    func scrollToButtom() {
        textview.selectedRange = NSRange(location: textview.text.count, length: 0)
        textview.isScrollEnabled = true
        
        let scrollY = textview.contentSize.height - textview.bounds.height
        let scrollPoint = CGPoint(x: 0, y: scrollY > 0 ? scrollY : 0)
        textview.setContentOffset(scrollPoint, animated: false)
    }
    
}

