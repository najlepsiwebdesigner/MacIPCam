import Darwin

func getLanIP() -> String {
    var address = "unknown"
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return address }
    defer { freeifaddrs(ifaddr) }

    var ptr = firstAddr
    let preferred = ["en0", "en1"]

    outer: for iface in preferred {
        var current: UnsafeMutablePointer<ifaddrs>? = ptr
        while let addr = current {
            let name = String(cString: addr.pointee.ifa_name)
            if name == iface, addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr.pointee.ifa_addr, socklen_t(addr.pointee.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    address = String(cString: hostname)
                    break outer
                }
            }
            current = addr.pointee.ifa_next
        }
        ptr = firstAddr
    }
    return address
}
