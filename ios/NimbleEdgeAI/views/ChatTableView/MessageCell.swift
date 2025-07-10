/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit
import SwiftUICore
import Foundation
import MarkdownKit

class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"
    
    //padding constants [used for calculating cell height]
    static let verticalPadding: CGFloat = 8
    static let topMargin: CGFloat = 12
    static let bottomMargin: CGFloat = 8
    static let horizontalMargin: CGFloat = 12
    static let horizontalPadding: CGFloat = 15
    static let spacing: CGFloat = 5
    static let weightMultiplier: CGFloat = 0.8
    
    // MARK: - UI Elements initialized lazily
    
    lazy var bubbleView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(messageLabel)
        view.addSubview(timestampLabel)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: MessageCell.topMargin),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: MessageCell.horizontalMargin),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -MessageCell.horizontalMargin),
            
            timestampLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 5),
            timestampLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -MessageCell.bottomMargin),
            timestampLabel.trailingAnchor.constraint(equalTo: messageLabel.trailingAnchor),
            timestampLabel.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor)
        ])
        return view
    }()
    
    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    }()
    
    // MARK: - Loader properties
    private var bubbleViewLeadingAnchor: NSLayoutConstraint?
    private var bubbleViewtrailingAnchor: NSLayoutConstraint?
    private var markdownFormatter = {
        var formatter = MarkdownParser(font: UIFont.systemFont(ofSize: 16), color: UIColor(Color.textPrimary))
        return formatter
    }()

    
    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViewHierarchy()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    // MARK: - Setup
    
    private func setupViewHierarchy() {
        contentView.backgroundColor = .clear
        contentView.addSubview(bubbleView)
    }
    
    private func setupConstraints() {
        bubbleViewLeadingAnchor = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: MessageCell.horizontalPadding)
        bubbleViewtrailingAnchor = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -MessageCell.horizontalPadding)
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: MessageCell.verticalPadding),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -MessageCell.verticalPadding),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: MessageCell.weightMultiplier),
        ])

    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage) {
        resetUI()
        
        bubbleView.backgroundColor = message.isUserMessage ? UIColor(Color.backgroundSecondary) : UIColor(Color.accentLow1)
        
        // Text alignments
        if message.isUserMessage {
            bubbleViewtrailingAnchor?.isActive = true
            messageLabel.textAlignment = .right
        } else {
            bubbleViewLeadingAnchor?.isActive = true
            messageLabel.textAlignment = .left
        }
        
        guard let text = message.message else { return }
        
        messageLabel.attributedText = markdownFormatter.parse(text)
        timestampLabel.text = formattedDate(date: message.timestamp) + (message.isUserMessage ? " • sent" : "")
        
    }
    
    func set(with message: ChatMessage) {
        guard let text = message.message else { return }

        messageLabel.attributedText = markdownFormatter.parse(text)
        timestampLabel.text = formattedDate(date: message.timestamp) + (message.isUserMessage ? " • sent" : "")
    }

    private func resetUI() {
        bubbleViewtrailingAnchor?.isActive = false
        bubbleViewLeadingAnchor?.isActive = false
    }
    
    // MARK: - Helpers
    
    private func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
