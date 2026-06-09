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

class OutboxButton: UIControl {
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let colorOverlayView = UIView()
    private let iconView = UIImageView()
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
        // Parent view has cornerRadius and masksToBounds = false to allow shadow
        layer.cornerRadius = 28
        layer.masksToBounds = false
        layer.borderWidth = 0.5
        updateBorderColor()
        
        // Subview blurEffectView clips its own content
        blurEffectView.layer.cornerRadius = 28
        blurEffectView.layer.masksToBounds = true
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurEffectView)
        
        colorOverlayView.translatesAutoresizingMaskIntoConstraints = false
        updateColorOverlay()
        blurEffectView.contentView.addSubview(colorOverlayView)
        
        iconView.image = UIImage(systemName: "shippingbox")?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .secondaryLabel
        iconView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(iconView)
        
        badgeContainer.backgroundColor = .systemRed
        badgeContainer.layer.cornerRadius = 9
        badgeContainer.layer.masksToBounds = true
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(badgeContainer)
        
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        
        NSLayoutConstraint.activate([
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            colorOverlayView.leadingAnchor.constraint(equalTo: blurEffectView.contentView.leadingAnchor),
            colorOverlayView.trailingAnchor.constraint(equalTo: blurEffectView.contentView.trailingAnchor),
            colorOverlayView.topAnchor.constraint(equalTo: blurEffectView.contentView.topAnchor),
            colorOverlayView.bottomAnchor.constraint(equalTo: blurEffectView.contentView.bottomAnchor),
            
            iconView.centerXAnchor.constraint(equalTo: blurEffectView.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: blurEffectView.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            badgeContainer.topAnchor.constraint(equalTo: iconView.topAnchor, constant: -6),
            badgeContainer.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            badgeContainer.heightAnchor.constraint(equalToConstant: 18),
            badgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 4),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -4),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor)
        ])
        
        setBadge(count: 0)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
            updateColorOverlay()
        }
    }
    
    private func updateBorderColor() {
        if #available(iOS 13.0, *) {
            layer.borderColor = UIColor { trait in
                return trait.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.15)
                    : UIColor(white: 1.0, alpha: 0.45)
            }.cgColor
        } else {
            layer.borderColor = UIColor(white: 1.0, alpha: 0.45).cgColor
        }
    }
    
    private func updateColorOverlay() {
        if #available(iOS 13.0, *) {
            colorOverlayView.backgroundColor = traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.0, alpha: 0.12)
                : UIColor(white: 1.0, alpha: 0.4)
        } else {
            colorOverlayView.backgroundColor = UIColor(white: 1.0, alpha: 0.4)
        }
    }
    
    func setBadge(count: Int) {
        if count <= 0 {
            badgeContainer.isHidden = true
            iconView.tintColor = .secondaryLabel
        } else {
            badgeContainer.isHidden = false
            iconView.tintColor = .label
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
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: nil)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.transform = .identity
        }, completion: nil)
        sendActions(for: .touchUpInside)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.transform = .identity
        }, completion: nil)
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
    
    private func setupView() {
        backgroundColor = .clear
        
        // 1. Standard Apple UITabBar Configuration
        systemTabBar.delegate = self
        systemTabBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(systemTabBar)
        
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        systemTabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            systemTabBar.scrollEdgeAppearance = appearance
        }
        
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
            // systemTabBar spanning full width at bottom, standard height 49 + safe area bottom inset
            systemTabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            systemTabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            systemTabBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            systemTabBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -49),
            
            // outboxButton floating in bottom right, 20pt from edge, 16pt above the system tab bar
            outboxButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            outboxButton.bottomAnchor.constraint(equalTo: systemTabBar.topAnchor, constant: -16),
            outboxButton.widthAnchor.constraint(equalToConstant: 56),
            outboxButton.heightAnchor.constraint(equalToConstant: 56)
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
