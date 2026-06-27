// DefaultPAC — Generate PAC (Proxy Auto-Config) file content
// Strategy: proxy all traffic through SOCKS5 except common domestic domains

import Foundation

enum DefaultPAC {

    /// Generate PAC file content with SOCKS5 proxy
    static func generate(socks5Host: String, socks5Port: UInt16) -> String {
        let proxyStr = "SOCKS5 \(socks5Host):\(socks5Port); SOCKS \(socks5Host):\(socks5Port); DIRECT"

        return """
        function FindProxyForURL(url, host) {
            // === Direct connection for local/private addresses ===
            if (isPlainHostName(host)) return "DIRECT";
            if (shExpMatch(host, "127.0.0.*")) return "DIRECT";
            if (shExpMatch(host, "localhost")) return "DIRECT";
            if (shExpMatch(host, "10.*")) return "DIRECT";
            if (shExpMatch(host, "172.16.*") || shExpMatch(host, "172.17.*") || shExpMatch(host, "172.18.*") || shExpMatch(host, "172.19.*")) return "DIRECT";
            if (shExpMatch(host, "172.20.*") || shExpMatch(host, "172.21.*") || shExpMatch(host, "172.22.*") || shExpMatch(host, "172.23.*")) return "DIRECT";
            if (shExpMatch(host, "172.24.*") || shExpMatch(host, "172.25.*") || shExpMatch(host, "172.26.*") || shExpMatch(host, "172.27.*")) return "DIRECT";
            if (shExpMatch(host, "172.28.*") || shExpMatch(host, "172.29.*") || shExpMatch(host, "172.30.*") || shExpMatch(host, "172.31.*")) return "DIRECT";
            if (shExpMatch(host, "192.168.*")) return "DIRECT";
            if (shExpMatch(host, "::1")) return "DIRECT";

            // === Direct connection for common domestic (CN) domains ===
            // This is a simplified list — users should update based on their needs
            var cnDomains = [
                ".cn",
                ".com.cn",
                ".edu.cn",
                ".gov.cn",
                ".org.cn",
                ".net.cn",
                ".ac.cn",
                ".ah.cn",
                ".bj.cn",
                ".cq.cn",
                ".fj.cn",
                ".gd.cn",
                ".gs.cn",
                ".gx.cn",
                ".gz.cn",
                ".hk.cn",
                ".hl.cn",
                ".hn.cn",
                ".jl.cn",
                ".js.cn",
                ".ln.cn",
                ".mo.cn",
                ".nm.cn",
                ".nx.cn",
                ".qh.cn",
                ".sc.cn",
                ".sd.cn",
                ".sh.cn",
                ".sn.cn",
                ".sx.cn",
                ".tj.cn",
                ".tw.cn",
                ".xj.cn",
                ".xz.cn",
                ".yn.cn",
                ".zj.cn",
                "baidu.com",
                "qq.com",
                "taobao.com",
                "tmall.com",
                "alipay.com",
                "weibo.com",
                "163.com",
                "126.com",
                "sina.com",
                "sohu.com",
                "jd.com",
                "douban.com",
                "zhihu.com",
                "bilibili.com",
                "aliyun.com",
                "csdn.net",
                "douyin.com",
                "toutiao.com",
                "meituan.com",
                "dianping.com",
                "ctrip.com",
                "12306.cn",
                "icbc.com.cn",
                "ccb.com",
                "boc.cn",
                "abchina.com",
                "psbc.com"
            ];

            for (var i = 0; i < cnDomains.length; i++) {
                if (host.endsWith(cnDomains[i]) || shExpMatch(host, "*" + cnDomains[i])) {
                    return "DIRECT";
                }
            }

            // === Direct for common local services ===
            if (shExpMatch(host, "*.local")) return "DIRECT";
            if (shExpMatch(host, "*.mDNSResponder")) return "DIRECT";

            // === Everything else goes through proxy ===
            return "\(proxyStr)";
        }
        """
    }
}
