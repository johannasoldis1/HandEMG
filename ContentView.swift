import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var graph: emgGraph
    @ObservedObject var BLE: BLEManager
    @State private var showingExporter = false
    @State var file_content: TextFile = TextFile(initialText: "")

    var body: some View {
        VStack(spacing: 10) {
            // Raw EMG Graph
            VStack {
                Text("Raw EMG Data")
                    .font(.headline)
                    .padding(.top, 50) // Increased padding to avoid front camera obstruction
                
                Path { path in
                    let height = UIScreen.main.bounds.height / 6
                    let width = UIScreen.main.bounds.width

                    // Ensure valid data range
                    guard graph.values.count > 1 else { return }

                    let firstSample = { () -> Int in
                        if graph.values.count > 50 {
                            return graph.values.count - 50
                        } else {
                            return 0
                        }
                    }
                    let cutGraph = graph.values[firstSample()..<graph.values.count]

                    // Start drawing at the first valid data point
                    path.move(to: CGPoint(x: 0.0, y: height)) // * (1.0 - cutGraph.first!))
                    
                    cutGraph.enumerated().forEach { index, item in
                        path.addLine(to: CGPoint(
                            x: width * CGFloat(index) / (CGFloat(cutGraph.count) - 1.0),
                            y: height * (1.0 - item)
                        ))
                    }
                }
                .stroke(Color.blue, lineWidth: 1.5)
            }
            .frame(height: 150)

            // RMS Graph
            VStack {
                Text("RMS Data")
                    .font(.headline)
                    .padding(.top, 20)
                
                Path { path in
                    let height = UIScreen.main.bounds.height / 8
                    let width = UIScreen.main.bounds.width
                    let history = BLE.rmsHistory
                    
                    guard !history.isEmpty else { return }
                    
                    let startX = CGFloat(0)
                    let stepX = width / CGFloat(history.count - 1)
                    
                    path.move(to: CGPoint(x: startX, y: height))
                    
                    for (index, value) in history.enumerated() {
                        let x = startX + CGFloat(index) * stepX
                        let y = height * (1.0 - CGFloat(value)) // Invert to fit graph height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.red, lineWidth: 2.0)
            }
            .frame(height: 120)

            // Text to see the current RMS value
            Text("Current RMS: \(BLE.currentRMS, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.red)
                .padding()

            if !BLE.isConnected {
                // Show connection options only if not connected
                VStack {
                    Text("Connect to Sensor")
                        .font(.title)
                        .frame(maxWidth: .infinity, alignment: .center)

                    List(BLE.BLEPeripherals) { peripheral in
                        HStack {
                            Text(peripheral.name).onTapGesture {
                                print(peripheral)
                                BLE.connectSensor(p: peripheral)
                            }
                            Spacer()
                            Text(String(peripheral.rssi))
                        }
                    }
                    .frame(height: 150)
                }
            } else {
                // Display a message when connected
                Text("Connected to EMGBLE2!")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            // Status display
            Text("STATUS")
                .font(.headline)
            if BLE.BLEisOn {
                Text("Bluetooth is switched on")
                    .foregroundColor(.green)
            } else {
                Text("Bluetooth is NOT switched on")
                    .foregroundColor(.red)
            }

            // Buttons for Bluetooth scanning and recording
            HStack {
                VStack(spacing: 10) { // Vertically stacked scanning buttons on the left
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
                }
                .padding()

                Spacer()

                VStack(spacing: 10) { // Vertically stacked recording buttons on the right
                    Button(action: {
                        graph.record()
                    }) {
                        Text("Start Recording")
                    }
                    Button(action: {
                        file_content.text = graph.stop_recording_and_save()
                    }) {
                        Text("Stop Recording")
                    }
                    Button(action: {
                        showingExporter = true
                    }) {
                        Text("Export last")
                    }
                }
                .padding()
            }

            Spacer()
        }
        .fileExporter(isPresented: $showingExporter, document: file_content, contentType: .commaSeparatedText, defaultFilename: "emg-data") { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        .padding(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let graph = emgGraph(firstValues: Array(repeating: 0.5, count: 100)).enableDummyData()
        let BLE = BLEManager(emg: graph)
        BLE.startDummyData() // Enable dummy data in preview
        return ContentView(graph: graph, BLE: BLE)
            .previewInterfaceOrientation(.portrait)
    }
}

struct TextFile: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText]
    static var preferredFilenameExtension: String? { "csv" }
    var text = ""

    init(initialText: String = "") {
        text = initialText
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

