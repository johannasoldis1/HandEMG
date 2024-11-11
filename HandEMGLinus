//
//  File.swift
//  EMG-ble-kth
//
//  Created by Linus Remahl on 2021-11-01.
//

import Foundation
import CoreBluetooth

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    var myCentral: CBCentralManager!
    @Published var BLEisOn = false
    @Published var isConnected = false
    @Published var BLEPeripherals = [Peripheral]()
    var CBPeripherals = [CBPeripheral]()
    var emg:emgGraph!
    
    init(emg:emgGraph) {
        super.init()
 
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
        
        self.emg = emg
        
    }
    
    override init() {
                super.init()
         
                myCentral = CBCentralManager(delegate: self, queue: nil)
                myCentral.delegate = self
            }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
             if central.state == .poweredOn {
                 BLEisOn = true
             }
             else {
                 BLEisOn = false
             }
        }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!
           
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralName = name
        }
        else {
            peripheralName = "Unknown"
        }
           
        let newPeripheral = Peripheral(id: BLEPeripherals.count, name: peripheralName, rssi: RSSI.intValue)
        print(newPeripheral)
        BLEPeripherals.append(newPeripheral)
        CBPeripherals.append(peripheral)
    }
        
    func startScanning() {
        //let emgServiceCBUUID = CBUUID(string: "4028F84C-05C0-4181-843E-BDBEE6E1030D")
        print("startScanning")
        BLEPeripherals.removeAll()
        CBPeripherals.removeAll()
        //myCentral.scanForPeripherals(withServices: [emgServiceCBUUID], options: nil)
        myCentral.scanForPeripherals(withServices: nil)
    }
        
    func stopScanning() {
        print("stopScanning")
        myCentral.stopScan()
    }
    
    func connectSensor(p:Peripheral){
        myCentral.connect(CBPeripherals[p.id])
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print(peripheral)
        print("Connected!")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
    }
    
}

extension BLEManager:CBPeripheralDelegate {
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
      guard let characteristics = service.characteristics else { return }

      for characteristic in characteristics {
        if characteristic.properties.contains(.read) {
            print("\(characteristic.uuid): properties contains .read")
        }
        if characteristic.properties.contains(.notify) {
            print("\(characteristic.uuid): properties contains .notify")
            peripheral.setNotifyValue(true, for: characteristic)
        }
        print(characteristic)
          
      }
        
    }
    
    //This is the function which catches the data from the sensor
    //Currently packs the data back into 16-bits, and then scales from 0-1
    //Does not care at what rate the data is coming in.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
      switch characteristic.uuid {
      case CBUUID(string:"E399EFC0-79F9-4E08-82A8-F3AA1DC609F1"):
          guard let characteristicData = characteristic.value else {return}
          let byteArray = [UInt8](characteristicData)
          var graphData: Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0,
                                         0.0, 0.0, 0.0, 0.0, 0.0]
          var toggle = false
          var count = 0
          for bt in byteArray {
              if toggle && !graphData.isEmpty{
                  graphData[count] += Float(bt)*(256.0)
                  graphData[count] /= 4096.0
                  count += 1
              }
              else {
                  graphData[count] = Float(bt)
              }
              toggle.toggle()
              
          }
          print(graphData)
          emg.append(values:graphData)
          
        default:
          print("Unhandled Characteristic UUID: \(characteristic.uuid)")
      }
    }
    
}
