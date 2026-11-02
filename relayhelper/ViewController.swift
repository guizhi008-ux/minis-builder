import UIKit
import NetworkExtension

class ViewController: UIViewController {

    // 与 v5 描述文件完全一致的参数
    private let relayURLString = "https://relay.6642.eu.org"
    private let excludedDomains: [String] = [
        "cn", "52hy.eu.org", "6642.eu.org", "relay.6642.eu.org",
        "qq.com", "weixin.qq.com", "wechat.com", "tencent.com",
        "baidu.com", "bdstatic.com", "taobao.com", "tmall.com",
        "alipay.com", "jd.com", "jingdong.com", "weibo.com",
        "sina.com.cn", "zhihu.com", "bilibili.com", "douyin.com",
        "snssdk.com", "bytedance.com", "xiaohongshu.com", "meituan.com",
        "dianping.com", "netease.com", "163.com", "126.com",
        "sohu.com", "ifeng.com", "cctv.com", "people.com.cn",
        "xinhuanet.com", "gov.cn", "edu.cn", "12306.cn",
        "icbc.com.cn", "ccb.com", "abchina.com", "boc.cn",
        "cmbchina.com", "amap.com", "autonavi.com", "didiglobal.com",
        "kuaishou.com", "pinduoduo.com", "yangkeduo.com", "ele.me",
        "ctrip.com", "qunar.com", "mi.com", "xiaomi.com",
        "huawei.com", "huaweicloud.com", "vmall.com", "oppo.com",
        "vivo.com.cn", "honor.com", "icloud.com.cn", "aliyun.com",
        "alicdn.com", "mmstat.com", "youku.com", "iqiyi.com",
        "v.qq.com",
    ]

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let resultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        refreshStatus()
    }

    private func setupUI() {
        titleLabel.text = "Muse 中继助手"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textAlignment = .center

        statusLabel.text = "正在读取中继状态…"
        statusLabel.font = .systemFont(ofSize: 19)
        statusLabel.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        var attrs = AttributeContainer()
        attrs.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        config.attributedTitle = AttributedString("重新激活中继", attributes: attrs)
        config.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        actionButton.configuration = config
        actionButton.addTarget(self, action: #selector(reactivateTapped), for: .touchUpInside)

        resultLabel.text = ""
        resultLabel.font = .systemFont(ofSize: 17)
        resultLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, actionButton, resultLabel])
        stack.axis = .vertical
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
        ])
    }

    // MARK: - 读取当前状态

    private func refreshStatus() {
        let manager = NERelayManager.shared()
        manager.loadFromPreferences { [weak self] loadError in
            guard let self = self else { return }
            if let loadError = loadError {
                DispatchQueue.main.async {
                    let ns = loadError as NSError
                    self.statusLabel.text = "读取状态失败\n\(loadError.localizedDescription)\n域：\(ns.domain) 代码：\(ns.code)"
                }
                return
            }
            NERelayManager.loadAllManagersFromPreferences { [weak self] managers, listError in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let listError = listError {
                        let ns = listError as NSError
                        self.statusLabel.text = "读取配置列表失败\n\(listError.localizedDescription)\n域：\(ns.domain) 代码：\(ns.code)"
                        return
                    }
                    var lines: [String] = []
                    lines.append("当前中继状态：\(manager.isEnabled ? "✅ 已启用" : "⛔ 未启用")")
                    if let relays = manager.relays, !relays.isEmpty {
                        let urls = relays.compactMap { $0.http2RelayURL?.absoluteString ?? $0.http3RelayURL?.absoluteString }
                        lines.append("中继地址：\(urls.joined(separator: "，"))")
                    } else {
                        lines.append("中继地址：（本 App 尚未保存过配置）")
                    }
                    lines.append("直连名单：\(manager.excludedDomains?.count ?? 0) 条")
                    lines.append("本 App 名下的中继配置共 \(managers.count) 条")
                    for (index, m) in managers.enumerated() {
                        lines.append("第 \(index + 1) 条：\(m.isEnabled ? "已启用" : "未启用")")
                    }
                    self.statusLabel.text = lines.joined(separator: "\n")
                }
            }
        }
    }

    // MARK: - 重新激活

    @objc private func reactivateTapped() {
        actionButton.isEnabled = false
        resultLabel.text = "正在保存…如果系统弹出确认框，请点允许。"
        let manager = NERelayManager.shared()
        manager.loadFromPreferences { [weak self] loadError in
            guard let self = self else { return }
            if let loadError = loadError {
                DispatchQueue.main.async {
                    let ns = loadError as NSError
                    self.actionButton.isEnabled = true
                    self.resultLabel.text = "❌ 读取现有配置失败\n\(loadError.localizedDescription)\n域：\(ns.domain) 代码：\(ns.code)"
                }
                return
            }
            let relay = NERelay()
            relay.http2RelayURL = URL(string: self.relayURLString)
            manager.relays = [relay]
            manager.excludedDomains = self.excludedDomains
            manager.matchDomains = nil
            manager.localizedDescription = "Muse 中继"
            manager.isEnabled = true
            manager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.actionButton.isEnabled = true
                    if let saveError = saveError {
                        let ns = saveError as NSError
                        self.resultLabel.text = "❌ 保存失败\n\(saveError.localizedDescription)\n域：\(ns.domain) 代码：\(ns.code)"
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm:ss"
                        self.resultLabel.text = "✅ 已重新保存并启用（\(formatter.string(from: Date()))）"
                        self.refreshStatus()
                    }
                }
            }
        }
    }
}
