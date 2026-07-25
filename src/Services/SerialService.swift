import Foundation
import IOKit
import IOKit.serial

final class SerialService: ObservableObject {
    @Published var isConnected = false
    @Published var availablePorts: [String] = []

    private var fileDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var portPath: String?

    var onDataReceived: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    func refreshPorts() {
        var ports: [String] = []

        // Primary: IOKit enumeration
        var portIterator: io_iterator_t = 0
        let matching = IOServiceMatching(kIOSerialBSDServiceValue)
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &portIterator)
        if result == KERN_SUCCESS {
            var service = IOIteratorNext(portIterator)
            while service != 0 {
                if let name = IORegistryEntryCreateCFProperty(service, "IOCalloutDevice" as CFString, nil, 0)?.takeRetainedValue() as? String {
                    ports.append(name)
                }
                IOObjectRelease(service)
                service = IOIteratorNext(portIterator)
            }
            IOObjectRelease(portIterator)
        }

        // Fallback: list /dev/cu.* if IOKit found nothing
        if ports.isEmpty {
            let fm = FileManager.default
            if let devContents = try? fm.contentsOfDirectory(atPath: "/dev") {
                for item in devContents.sorted() {
                    if item.hasPrefix("cu.") {
                        let path = "/dev/\(item)"
                        if !ports.contains(path) {
                            ports.append(path)
                        }
                    }
                }
            }
        }

        availablePorts = ports
    }

    func connect(port: String, baudRate: Int32) {
        disconnect()

        let fd = open(port, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            DispatchQueue.main.async { self.onError?("Failed to open port: \(port)") }
            return
        }

        var tty = termios()
        tcgetattr(fd, &tty)

        let speed: speed_t
        switch baudRate {
        case 1200:  speed = speed_t(B1200)
        case 2400:  speed = speed_t(B2400)
        case 4800:  speed = speed_t(B4800)
        case 9600:  speed = speed_t(B9600)
        case 19200: speed = speed_t(B19200)
        case 38400: speed = speed_t(B38400)
        case 57600: speed = speed_t(B57600)
        case 115200: speed = speed_t(B115200)
        default:    speed = speed_t(B9600)
        }
        cfsetspeed(&tty, speed)

        tty.c_iflag &= ~UInt(ICRNL | IXON | IXOFF | IXANY)
        tty.c_oflag &= ~UInt(OPOST | ONLCR)
        tty.c_cflag &= ~UInt(CSIZE | PARENB | CSTOPB | CRTSCTS)
        tty.c_cflag |= UInt(CS8 | CLOCAL | CREAD)
        tty.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG | IEXTEN)
        tty.c_cc.16 = 1  // VMIN
        tty.c_cc.17 = 0  // VTIME

        tcsetattr(fd, TCSANOW, &tty)
        tcflush(fd, TCIOFLUSH)

        fileDescriptor = fd
        portPath = port

        let readQueue = DispatchQueue(label: "com.wk3app.serial.read", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: readQueue)
        source.setEventHandler { [weak self] in
            let buffer = UnsafeMutableRawPointer.allocate(byteCount: 1024, alignment: 1)
            defer { buffer.deallocate() }
            let bytesRead = read(fd, buffer, 1024)
            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                DispatchQueue.main.async { self?.onDataReceived?(data) }
            } else if bytesRead < 0 {
                DispatchQueue.main.async { self?.onError?("Read error: \(String(cString: strerror(errno)))") }
            }
        }
        source.setCancelHandler { [weak self] in
            close(fd)
            DispatchQueue.main.async { self?.isConnected = false }
        }

        readSource = source
        source.resume()
        DispatchQueue.main.async { self.isConnected = true }
    }

    func disconnect() {
        readSource?.cancel()
        readSource = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        portPath = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    func send(_ data: Data) -> Bool {
        guard fileDescriptor >= 0 else { return false }
        return data.withUnsafeBytes { ptr in
            guard let basePtr = ptr.baseAddress else { return false }
            let result = write(fileDescriptor, basePtr, data.count)
            return result == data.count
        }
    }

    func sendBytes(_ bytes: [UInt8]) -> Bool {
        send(Data(bytes))
    }
}
