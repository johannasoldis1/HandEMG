//
//  ContentView.swift
//  EMG-ble-kth
//
//  Created by Linus Remahl on 2021-10-29.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var graph: emgGraph
    @ObservedObject var BLE: BLEManager
    @State private var showingExporter = false
    @State var file_content: TextFile = TextFile.init(initialText:"")
    
    var body: some View {
        VStack {
            //This part is the graph. It's really just a plain path, but graphs with higher abstraction usually aren't great for realtime updates.
            //Currently set to display last 1000 values
            Path{ path in
                let height = UIScreen.main.bounds.height / 3
                let width = UIScreen.main.bounds.width
                let firstSample = { () -> Int in
                    if graph.values.count > 1000 {
                            return graph.values.count - 1000
                    }
                    else {
                            return 0
                    }
                }
                let cutGraph = graph.values[firstSample()..<graph.values.count]
                let midY = height / 2  // Set the midpoint for -1 to 1 range

                path.move(to: CGPoint(x: 0.0, y: midY))

                cutGraph.enumerated().forEach { index, item in
                    path.addLine(
                        to: CGPoint(
                            x: width * CGFloat(index) / (CGFloat(cutGraph.count) - 1.0),
                            y: midY - (height / 2 * CGFloat(item)) // scale to -1 to 1
                        )
                    )
                }

            }
            .stroke(Color.red, lineWidth: 1.5)
            
            Text("Connect to sensor")
                            .font(.title)
                            .frame(maxWidth: .infinity, alignment: .center)
            List(BLE.BLEPeripherals) { peripheral in
                HStack {
                    Text(peripheral.name).onTapGesture {
                        print(peripheral)
                        BLE.connectSensor(p:peripheral)
                    }
                    Spacer()
                    Text(String(peripheral.rssi))
                }
            }.frame(height: 300)

            // Adding a blue line to start working on filtering
            
            Path{ path in
                let height = UIScreen.main.bounds.height / 3
                let width = UIScreen.main.bounds.width
                let firstSample = { () -> Int in
                    if graph.values.count > 1000 {
                            return graph.values.count - 1000
                    }
                    else {
                            return 0
                    }
                }
                let cutGraph = graph.values[firstSample()..<graph.values.count]
                path.move(to: CGPoint(x:0.0, y:0.0))
                
                cutGraph.enumerated().forEach { index, item in
                    path.addLine(to: CGPoint(x:width*CGFloat(index)/(CGFloat(cutGraph.count)-1.0), y:height*item))
                }
            }
            .stroke(Color.blue, lineWidth: 1.5)
            
            Spacer()

            Text("STATUS")
                .font(.headline)

                        // Status goes here
            if BLE.BLEisOn {
                Text("Bluetooth is switched on")
                    .foregroundColor(.green)
            }
            else {
                Text("Bluetooth is NOT switched on")
                    .foregroundColor(.red)
            }

            Spacer()

            HStack {
                VStack (spacing: 10) {
                    Button(action: {
                        BLE.startScanning()
                    }) {
                        Text("Start Scanning")
                    }
                    Button(action: {
                        BLE.stopScanning()
                    }) {
                        Text("Stop Scanning")
                    }
                }.padding()

                Spacer()
                
                VStack (spacing: 10) {
                    Button(action: {
                        graph.record()
                    }) {
                        Text("Start Recording")
                    }
                    Button(action: {
                        file_content.text = graph.stop_recording_and_save()
                    })
                    {
                        Text("Stop Recording")
                    }
                    Button(action: {
                        showingExporter = true
                    })
                    {
                        Text("Export last")
                    }
                
                }.padding()

            }
            Spacer()
        }.fileExporter(isPresented: $showingExporter, document: file_content, contentType: .commaSeparatedText, defaultFilename: "emg-data") { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let data: Array<CGFloat> = [
            0.5, 0.6, 0.3, 0.2, 0.4, 0.6, 0, 0.2, 0.5, 0.3, 0.6,
            0.5, 0.6, 0.3, 0.2, 0.4, 0.6, 0, 0.2, 0.5, 0.3, 0.6,
            0.5, 0.6, 0.3, 0.2, 0.4, 0.6, 0, 0.2, 0.5, 0.3, 0.6,
            0.5, 0.6, 0.3, 0.2, 0.4, 0.6, 0, 0.2, 0.5, 0.3, 0.6,
            0.5, 0.6, 0.3, 0.2, 0.4, 0.6, 0, 0.2, 0.5, 0.3, 0.6,
        ]
        let graph = emgGraph(firstValues:data).enableDummyData()
        let BLE = BLEManager()
        ContentView(graph:graph, BLE:BLE)
.previewInterfaceOrientation(.portrait)
    }
}


struct TextFile: FileDocument {
    // tell the system we support only plain text
    static var readableContentTypes = [UTType.commaSeparatedText]
    static var preferredFilenameExtension: String? { "csv" }
    // by default our document is empty
    var text = ""

    // a simple initializer that creates new, empty documents
    init(initialText: String = "") {
        text = initialText
    }

    // this initializer loads data that has been saved previously
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    // this will be called when the system wants to write our data to disk
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
