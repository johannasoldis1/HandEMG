import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var graph: emgGraph
    @ObservedObject var BLE: BLEManager
    @State private var showingExporter = false
    @State var file_content: TextFile = TextFile(initialText: "")

    var body: some View {
        VStack(spacing: 1) { // Adjust spacing between sections

            // Raw EMG Graph
            VStack {
                Text("Raw EMG Data")
                    .font(.headline)
                    .padding(.top, 10)

                Path { path in
                    let height = UIScreen.main.bounds.height / 6
                    let width = UIScreen.main.bounds.width

                    guard graph.values.count > 1 else { return }

                    let firstSample = { () -> Int in
                        if graph.values.count > 50 {
                            return graph.values.count - 50
                        } else {
                            return 0
                        }
                    }
                    let cutGraph = graph.values[firstSample()..<graph.values.count]
                    guard !cutGraph.isEmpty else { return }
                    let midY = height / 2

                    let startX = CGFloat(0)
                    let startY = midY - (height / 2 * CGFloat(cutGraph.first ?? 0))
                    path.move(to: CGPoint(x: startX, y: startY))

                    cutGraph.enumerated().forEach { index, item in
                        path.addLine(
                            to: CGPoint(
                                x: width * CGFloat(index) / (CGFloat(cutGraph.count) - 1.0),
                                y: midY - (height / 2 * CGFloat(item))
                            )
                        )
                    }
                }
                .stroke(Color.blue, lineWidth: 1.5)
                .frame(height: 150)
            }

            // RMS Graph
            VStack {
                Text("RMS Data")
                    .font(.headline)
                    .padding(.top, 10)

                Path { path in
                    let height = UIScreen.main.bounds.height / 8
                    let width = UIScreen.main.bounds.width
                    let history = BLE.rmsHistory

                    guard !history.isEmpty else { return }
                    let midY = height / 2

                    let startX = CGFloat(0)
                    let startY = midY - (height / 2 * CGFloat(history.first ?? 0))
                    path.move(to: CGPoint(x: startX, y: startY))

                    for (index, value) in history.enumerated() {
                        let x = startX + CGFloat(index) * (width / CGFloat(history.count - 1))
                        let y = midY - (height / 2 * CGFloat(value))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.red, lineWidth: 2.0)
                .frame(height: 120)
            }

            // Current RMS Value
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
                    .frame(height: 80)
                }
            } else {
                // Display a message when connected
                Text("Connected to EMGBLE2!")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            // Status Display
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
                VStack(spacing: 5) { // Vertically stacked scanning buttons
                    Button(action: {
                        BLE.startScanning()
                    }) {
                        Text("Start Scanning")
                    }
                    .disabled(BLE.isConnected) // Disable if connected

                    Button(action: {
                        BLE.stopScanning()
                    }) {
                        Text("Stop Scanning")
                    }
                    .disabled(!BLE.BLEisOn || BLE.isConnected) // Disable if Bluetooth is off or connected
                }
                .padding()

                Spacer()

                VStack(spacing: 10) { // Vertically stacked recording buttons
                    Button(action: {
                        DispatchQueue.global(qos: .background).async {
                            graph.record()
                            DispatchQueue.main.async {
                                print("Recording started.")
                            }
                        }
                    }) {
                        Text("Start Recording")
                    }

                    Button(action: {
                        DispatchQueue.global(qos: .background).async {
                            let fileContent = graph.stop_recording_and_save()
                            DispatchQueue.main.async {
                                file_content.text = fileContent
                                print("Recording stopped and saved.")
                            }
                        }
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

