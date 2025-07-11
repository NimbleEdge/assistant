/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit
import SwiftUICore

class LoaderCell: UITableViewCell {
    static let reuseIdentifier = "LoaderCell"
    var loaderTextProvider = LoaderTextProvider()
    
    private lazy var bubbleView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(activityIndicator)
        view.addSubview(loaderLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            activityIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            
            loaderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loaderLabel.leadingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 6),
            loaderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            loaderLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            loaderLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
        return view
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        return indicator
    }()
    
    private lazy var loaderLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(Color.textPrimary)
        label.font = UIFont.systemFont(ofSize: 17)
        label.text = loaderTextProvider.getLoaderText()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var loaderTimer: Timer?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        startLoader()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.backgroundColor = .clear
        contentView.addSubview(bubbleView)
        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.80)
        ])
        bubbleView.backgroundColor = UIColor(Color.accentLow1) // or your preferred color
    }
    
    private func startLoader() {
        loaderTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            UIView.transition(with: self.loaderLabel, duration: 0.3, options: .transitionCrossDissolve) {
                self.loaderLabel.text = self.loaderTextProvider.getLoaderText()
            }
        }
    }
    
    func stopLoader() {
        loaderTimer?.invalidate()
        loaderTimer = nil
        activityIndicator.stopAnimating()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stopLoader()
        activityIndicator.startAnimating()
        startLoader()
    }
}
