import UIKit

protocol NativeTabBarViewDelegate: AnyObject {
    func tabBarView(_ tabBarView: NativeTabBarView, didSelectTabAt index: Int)
    func tabBarViewDidTapOutbox(_ tabBarView: NativeTabBarView)
}

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

class OutboxButton: UIButton {
    private var blurEffectView: UIVisualEffectView?
    private var colorOverlayView: UIView?
    private var iconView: UIImageView?
    private let badgeLabel = UILabel()
    private let badgeContainer = UIView()
    
    init() {
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        if #available(iOS 26.0, *) {
            // 1. Use native glass configuration for iOS 26+
            var config = UIButton.Configuration.glass()
            config.image = UIImage(systemName: "shippingbox")
            config.imagePadding = 0
            config.cornerStyle = .capsule
            self.configuration = config
            
            // Set base tint color (applies to icon/text inside glass button)
            self.tintColor = .secondaryLabel
            
            setupBadge(isNativeGlass: true)
        } else {
            // 2. Fallback for older iOS versions
            setupFallbackView()
        }
    }
    
    private func setupBadge(isNativeGlass: Bool) {
        badgeContainer.backgroundColor = .systemRed
        badgeContainer.layer.cornerRadius = 9
        badgeContainer.layer.masksToBounds = true
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        
        if isNativeGlass {
            addSubview(badgeContainer)
        } else {
            blurEffectView?.contentView.addSubview(badgeContainer)
        }
        
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        
        NSLayoutConstraint.activate([
            badgeContainer.heightAnchor.constraint(equalToConstant: 18),
            badgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 4),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -4),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
        ])
        
        if isNativeGlass {
            NSLayoutConstraint.activate([
                badgeContainer.topAnchor.constraint(equalTo: self.topAnchor, constant: 14),
                badgeContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -14)
            ])
        }
        
        setBadge(count: 0)
    }
    
    private func setupFallbackView() {
        // Parent view has cornerRadius and masksToBounds = false to allow shadow
        layer.cornerRadius = 32
        layer.masksToBounds = false
        layer.borderWidth = 0.5
        updateBorderColor()
        updateBackgroundColor()
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.layer.cornerRadius = 32
        blur.layer.masksToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        self.blurEffectView = blur
        
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(overlay)
        self.colorOverlayView = overlay
        updateColorOverlay()
        
        let icon = UIImageView()
        icon.image = UIImage(systemName: "shippingbox")?.withRenderingMode(.alwaysTemplate)
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .secondaryLabel
        icon.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(icon)
        self.iconView = icon
        
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            overlay.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),
            
            icon.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        setupBadge(isNativeGlass: false)
        
        if let iconView = iconView {
            NSLayoutConstraint.activate([
                badgeContainer.topAnchor.constraint(equalTo: iconView.topAnchor, constant: -6),
                badgeContainer.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6)
            ])
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 26.0, *) {
            // System handles it
        } else {
            updateBorderColor()
            updateBackgroundColor()
            updateColorOverlay()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 26.0, *) {
            // System handles it
        } else {
            if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                setNeedsLayout()
            }
        }
    }
    
    private func updateBorderColor() {
        if #available(iOS 13.0, *) {
            layer.borderColor = UIColor { trait in
                return trait.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.15)
                    : UIColor(white: 0.0, alpha: 0.06)
            }.resolvedColor(with: traitCollection).cgColor
        } else {
            layer.borderColor = UIColor(white: 0.0, alpha: 0.06).cgColor
        }
    }
    
    private func updateBackgroundColor() {
        backgroundColor = .clear
    }
    
    private func updateColorOverlay() {
        if #available(iOS 13.0, *) {
            colorOverlayView?.backgroundColor = UIColor { trait in
                return trait.userInterfaceStyle == .dark
                    ? UIColor(red: 30/255.0, green: 30/255.0, blue: 32/255.0, alpha: 0.1)
                    : UIColor(red: 247/255.0, green: 249/255.0, blue: 253/255.0, alpha: 0.1)
            }.resolvedColor(with: traitCollection)
        } else {
            colorOverlayView?.backgroundColor = UIColor(red: 247/255.0, green: 249/255.0, blue: 253/255.0, alpha: 0.1)
        }
    }
    
    func setBadge(count: Int) {
        if count <= 0 {
            badgeContainer.isHidden = true
            if #available(iOS 26.0, *) {
                self.tintColor = .secondaryLabel
            } else {
                iconView?.tintColor = .secondaryLabel
            }
        } else {
            badgeContainer.isHidden = false
            if #available(iOS 26.0, *) {
                self.tintColor = .label
            } else {
                iconView?.tintColor = .label
            }
            if count > 99 {
                badgeLabel.text = "99+"
            } else {
                badgeLabel.text = "\(count)"
            }
        }
    }
    
    // Interactive Liquid Scale Animations
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if #available(iOS 26.0, *) {
            // Let the system handle native glass animations
        } else {
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: nil)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if #available(iOS 26.0, *) {
            // Let the system handle native glass animations
        } else {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.transform = .identity
            }, completion: nil)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        if #available(iOS 26.0, *) {
            // Let the system handle native glass animations
        } else {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.transform = .identity
            }, completion: nil)
        }
    }
}

class NativeTabBarView: UIView, UITabBarDelegate {
    weak var delegate: NativeTabBarViewDelegate?
    
    private let systemTabBar = UITabBar()
    private let outboxButton = OutboxButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            updateAppearance()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        if #available(iOS 13.0, *) {
            appearance.backgroundColor = UIColor { trait in
                return trait.userInterfaceStyle == .dark
                    ? UIColor(white: 0.1, alpha: 0.15)
                    : UIColor(white: 1.0, alpha: 0.15)
            }
        } else {
            appearance.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        }
        
        appearance.shadowColor = .clear
        
        systemTabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            systemTabBar.scrollEdgeAppearance = appearance
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let tabBarPoint = convert(point, to: systemTabBar)
        let outboxPoint = convert(point, to: outboxButton)
        
        return (!systemTabBar.isHidden && systemTabBar.point(inside: tabBarPoint, with: event)) ||
               (!outboxButton.isHidden && outboxButton.point(inside: outboxPoint, with: event))
    }
    
    private func setupView() {
        backgroundColor = .clear
        
        // 1. Standard Apple UITabBar Configuration
        systemTabBar.delegate = self
        systemTabBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(systemTabBar)
        
        updateAppearance()
        
        // 2. Outbox Glass Button Layout
        outboxButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Shadow for the floating button
        outboxButton.layer.shadowColor = UIColor.black.cgColor
        outboxButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        outboxButton.layer.shadowRadius = 12
        outboxButton.layer.shadowOpacity = 0.16
        outboxButton.layer.masksToBounds = false
        addSubview(outboxButton)
        
        NSLayoutConstraint.activate([
            systemTabBar.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            systemTabBar.trailingAnchor.constraint(equalTo: outboxButton.leadingAnchor, constant: -6),
            systemTabBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            systemTabBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -49),
            
            // outboxButton on the right: diameter 64, centerY adjusted to top + 30 to align with capsule bottom
            outboxButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -28),
            outboxButton.widthAnchor.constraint(equalToConstant: 64),
            outboxButton.heightAnchor.constraint(equalToConstant: 64),
            outboxButton.centerYAnchor.constraint(equalTo: systemTabBar.topAnchor, constant: 30)
        ])
        
        outboxButton.addTarget(self, action: #selector(outboxTapped), for: .touchUpInside)
    }
    
    // MARK: - UITabBarDelegate
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        delegate?.tabBarView(self, didSelectTabAt: item.tag)
    }
    
    @objc private func outboxTapped() {
        delegate?.tabBarViewDidTapOutbox(self)
    }
    
    func update(
        selectedIndex: Int,
        badgeCount: Int,
        primaryColorHex: String,
        connectLabel: String,
        filesLabel: String,
        settingsLabel: String
    ) {
        let primaryColor = UIColor(hex: primaryColorHex) ?? .systemBlue
        
        if systemTabBar.items == nil || systemTabBar.items?.count == 0 {
            let connectItem = UITabBarItem(title: connectLabel, image: UIImage(systemName: "personalhotspot"), tag: 0)
            let filesItem = UITabBarItem(title: filesLabel, image: UIImage(systemName: "folder"), tag: 1)
            let settingsItem = UITabBarItem(title: settingsLabel, image: UIImage(systemName: "gearshape"), tag: 2)
            
            systemTabBar.setItems([connectItem, filesItem, settingsItem], animated: false)
        } else {
            systemTabBar.items?[0].title = connectLabel
            systemTabBar.items?[1].title = filesLabel
            systemTabBar.items?[2].title = settingsLabel
        }
        
        systemTabBar.selectedItem = systemTabBar.items?[selectedIndex]
        systemTabBar.tintColor = primaryColor
        
        outboxButton.setBadge(count: badgeCount)
    }
}
