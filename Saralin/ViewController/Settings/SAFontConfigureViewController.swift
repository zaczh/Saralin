//
//  SAFontConfigureViewController.swift
//  Saralin
//
//  Created by zhang on 10/9/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit


class SAFontConfigureViewController: SABaseViewController {
    
    class FontAdjustSlider: UIView {
        let maximumFontLabel = UILabel()
        let minimalFontLabel = UILabel()
        let slider = UISlider.init()
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(slider)
            addSubview(minimalFontLabel)
            addSubview(maximumFontLabel)

            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.minimumValue = -10
            slider.maximumValue = 10
            slider.minimumTrackTintColor = UIColor.lightGray
            slider.maximumTrackTintColor = UIColor.lightGray
            slider.leftAnchor.constraint(equalTo: minimalFontLabel.rightAnchor, constant: 10).isActive = true
            slider.rightAnchor.constraint(equalTo: maximumFontLabel.leftAnchor, constant: -10).isActive = true
            slider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true

            let systemBodyFont = UIFont.preferredFont(forTextStyle: .body)
            minimalFontLabel.translatesAutoresizingMaskIntoConstraints = false
            minimalFontLabel.font = systemBodyFont.withSize(max(systemBodyFont.pointSize - 10, 1))
            minimalFontLabel.text = "小"
            minimalFontLabel.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor, constant: 0).isActive = true
            minimalFontLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor, constant: 0).isActive = true
            
            maximumFontLabel.translatesAutoresizingMaskIntoConstraints = false
            maximumFontLabel.font = systemBodyFont.withSize(systemBodyFont.pointSize + 10)
            maximumFontLabel.text = "大"
            maximumFontLabel.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
            maximumFontLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor, constant: 0).isActive = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var demoLabel = UILabel()
    private let dynamicTypeFontSwitch = UISwitch()
    private let dynamicTypeFontButton = UIButton()
    private let fontSlider = FontAdjustSlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = NSLocalizedString("OPTION_FONT_SETTING", comment: "OPTION_FONT_SETTING")
                
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        let vstack = UIStackView()
        vstack.spacing = 20
        vstack.alignment = .center
        vstack.axis = .vertical
        vstack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vstack)
        vstack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 20).isActive = true
        vstack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -20).isActive = true
        vstack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        vstack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        
        demoLabel.numberOfLines = 0
        vstack.addArrangedSubview(demoLabel)
        let textDemo = NSLocalizedString("FONT_CONFIGURE_VC_DEMO_TEXT", comment: "Font Configure VC Demo Text")
        demoLabel.text = "演示文字:\n\n\(textDemo)"
        demoLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        demoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        vstack.addArrangedSubview(fontSlider)
        fontSlider.widthAnchor.constraint(equalTo: vstack.widthAnchor, multiplier: 0.8).isActive = true
        fontSlider.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        let dynamicTypeStack = UIStackView()
        dynamicTypeStack.axis = .horizontal
        dynamicTypeStack.addArrangedSubview(dynamicTypeFontSwitch)
        dynamicTypeFontSwitch.addTarget(self, action: #selector(handleDynamicTypeSwitchClick(_:)), for: .valueChanged)
        dynamicTypeFontSwitch.isOn = (Account().preferenceForkey(.uses_system_dynamic_type_font) as? Bool) ?? true
        dynamicTypeStack.setCustomSpacing(10, after: dynamicTypeFontSwitch)
        
        dynamicTypeFontButton.setTitle("使用动态字体", for: .normal)
        dynamicTypeFontButton.setTitleColor(Theme().textColor.sa_toColor(), for: .normal)
        dynamicTypeStack.addArrangedSubview(dynamicTypeFontButton)
        vstack.addArrangedSubview(dynamicTypeStack)
        
        fontSlider.isHidden = ((Account().preferenceForkey(.uses_system_dynamic_type_font) as? Bool) ?? true)
        fontSlider.slider.value = Account().preferenceForkey(SAAccount.Preference.bodyFontSizeOffset) as! Float
        fontSlider.slider.addTarget(self, action: #selector(handleSliderValueChange(_:)), for: .valueChanged)
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        demoLabel.textColor = newTheme.textColor.sa_toColor()
        fontSlider.maximumFontLabel.textColor = newTheme.textColor.sa_toColor()
        fontSlider.minimalFontLabel.textColor = newTheme.textColor.sa_toColor()
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        demoLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
        dynamicTypeFontButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleSliderValueChange(_ sender: UISlider) {
        let value = sender.value as Float
        let roundedValue = round(value)
        Account().savePreferenceValue(roundedValue as AnyObject, forKey: SAAccount.Preference.bodyFontSizeOffset)
        sender.value = roundedValue
    }
    
    @objc func handleDynamicTypeSwitchClick(_ sender: UISwitch) {
        if sender.isOn {
            fontSlider.isHidden = true
            Account().savePreferenceValue(true as AnyObject, forKey: .uses_system_dynamic_type_font)
        } else {
            fontSlider.isHidden = false
            Account().savePreferenceValue(false as AnyObject, forKey: .uses_system_dynamic_type_font)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
