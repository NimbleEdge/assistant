/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit
import SwiftUI

struct ChatTableView: UIViewRepresentable {
    var chatViewModel: ChatViewModel
    var tableView: UITableView!
    
    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: ChatTableView
        var tableView: UITableView?
        var scrollToBottomButton: UIButton?
        private var reloadCellWorkItem: DispatchWorkItem?

        
        init(_ parent: ChatTableView) {
            self.parent = parent
            super.init()
            
            setupViewModel()
            setupKeyboard()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        func setupViewModel() {
            parent.chatViewModel.onOutputStreamUpdated = { [weak self] output in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Cancel any previous scheduled reload
                    self.reloadCellWorkItem?.cancel()
                    
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        let lastRow = self.parent.chatViewModel.chatHistory.count - 1
                        if lastRow < 0 { return }
                        let indexPath = IndexPath(row: lastRow, section: 0)
                        
                        guard let cell = self.tableView?.cellForRow(at: indexPath) as? MessageCell else {
                            UIView.performWithoutAnimation {
                                self.tableView?.beginUpdates()
                                self.tableView?.reloadRows(at: [indexPath], with: .none)
                                self.tableView?.endUpdates()
                            }
                            return
                        }
                        
                        let oldHeight = cell.messageLabel.frame.height
                        cell.set(with: self.parent.chatViewModel.chatHistory.last!)
                        
                        let maxSize = CGSize(width: cell.messageLabel.frame.width, height: CGFloat.greatestFiniteMagnitude)
                        let newHeight = cell.messageLabel.sizeThatFits(maxSize).height
                        
                        if newHeight != oldHeight {
                            UIView.performWithoutAnimation {
                                self.tableView?.beginUpdates()
                                self.tableView?.reloadRows(at: [indexPath], with: .none)
                                self.tableView?.endUpdates()
                            }
                            self.scrollToBottomIfNeeded(animated: false)
                        }
                    }
                    
                    self.reloadCellWorkItem = workItem
                    
                    //doing this to not make main thread overloaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: workItem)
                }
            }

            parent.chatViewModel.onNewMessageAdded = { [weak self] newChatMessage in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let lastRow = self.parent.chatViewModel.chatHistory.count - 1
                    let indexPath = IndexPath(row: lastRow, section: 0)
                    self.tableView?.insertRows(at: [indexPath], with: .bottom)
                    self.tableView?.scrollToRow(at: indexPath, at: .bottom, animated: true)
                }
            }
            
            parent.chatViewModel.onChatHistoryUpdated = { [weak self] chatHistory in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.tableView?.reloadData()
                }
            }
        }
        
        //MARK: TableView Delegate
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return parent.chatViewModel.chatHistory.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            let message = parent.chatViewModel.chatHistory[indexPath.row]

            // Showing loading cell when text is nil
            if (message.message ?? "").isEmpty {
                if let cell = tableView.dequeueReusableCell(withIdentifier: LoaderCell.reuseIdentifier) as? LoaderCell {
                    cell.selectionStyle = .none
                    cell.backgroundColor = .clear
                    return cell
                }
            } else {
                if let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseIdentifier) as? MessageCell {
                    cell.configure(with: message)
                    cell.selectionStyle = .none
                    cell.backgroundColor = .clear
                    return cell
                }
            }
            
            return UITableViewCell()
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return UITableView.automaticDimension
        }
        
        func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            let text = parent.chatViewModel.chatHistory[indexPath.row].message ?? ""
            let availableWidth = (tableView.bounds.width * MessageCell.weightMultiplier) - ((MessageCell.verticalPadding*2) + MessageCell.topMargin + MessageCell.bottomMargin)
            let textHeight = text.height(withConstrainedWidth: availableWidth, font: .systemFont(ofSize: 16))
            let timestampHeight = " ".height(withConstrainedWidth: availableWidth, font: UIFont.preferredFont(forTextStyle: .caption2))

            // Add any vertical padding for the cell's content
            let extraHeight: CGFloat = timestampHeight +  MessageCell.spacing + (MessageCell.horizontalMargin*2) + (MessageCell.horizontalPadding*2)
            
            return (textHeight + extraHeight)
        }
        
        //MARK: Context Menu
        func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
            let chatMessage = parent.chatViewModel.chatHistory[indexPath.row]
            return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
                UIMenu(title: "", children: [
                    UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                        UIPasteboard.general.string = chatMessage.message
                    }
                ])
            }
        }
        
        func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
            guard let indexPath = configuration.identifier as? IndexPath,
                  let cell = tableView.cellForRow(at: indexPath) as? MessageCell else {
                return nil
            }
            
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            return UITargetedPreview(view: cell.bubbleView, parameters: parameters)
        }
        
        
        func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
            guard let indexPath = configuration.identifier as? IndexPath,
                  let cell = tableView.cellForRow(at: indexPath) as? MessageCell else {
                return nil
            }
            
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            return UITargetedPreview(view: cell.bubbleView, parameters: parameters)
        }
        
        
        //MARK: Handling Scroll to Bottom
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let isUserScrolling = scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating
            
            if !isScrollAtBottom(scrollView, withOffSet: 30) && isUserScrolling {
                scrollToBottomButton?.isHidden = false
            } else {
                scrollToBottomButton?.isHidden = true
            }
        }
        
        func isScrollAtBottom(_ scrollView: UIScrollView, withOffSet: CGFloat = 80) -> Bool {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.size.height
            let isAtBottom = offsetY >= (contentHeight - frameHeight - withOffSet) // Tolerate small offset

            return isAtBottom
        }
        
        @objc func scrollToBottom(animated: Bool) {
            if let lastIndex = tableView?.numberOfRows(inSection: 0), lastIndex > 0 {
                tableView?.scrollToRow(at: IndexPath(row: (lastIndex - 1), section: 0), at: .bottom, animated: animated)
            }
        }
        
        //@objc overload without parameters for button
        @objc func scrollToBottomAction() {
            scrollToBottom(animated: true)
        }
        
        func scrollToBottomIfNeeded(animated: Bool = true) {
            if isScrollAtBottom(tableView!) {
                scrollToBottom(animated: animated)
            }
        }
        
        //MARK: Keyboard Handling
        func setupKeyboard() {
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        }
        
        @objc func keyboardWillShow(_ notification: Notification) {
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let keyboardHeight = keyboardFrame.cgRectValue.height
                
                // Get bottom safe area inset from the key window
                var bottomInset: CGFloat = 0
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    bottomInset = window.safeAreaInsets.bottom
                }
                
                // Subtract bottom safe area inset
                let adjustedHeight = keyboardHeight - bottomInset

                // Adjust tableView insets
                tableView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: adjustedHeight, right: 0)
                tableView?.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: adjustedHeight, right: 0)
                scrollToBottomIfNeeded()
            }
        }

        @objc func keyboardWillHide(_ notification: Notification) {
            tableView?.contentInset = .zero
            tableView?.scrollIndicatorInsets = .zero
            scrollToBottomIfNeeded()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseIdentifier)
        tableView.register(LoaderCell.self, forCellReuseIdentifier: LoaderCell.reuseIdentifier)
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.separatorStyle = .none
        tableView.automaticallyAdjustsScrollIndicatorInsets = true
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension

        context.coordinator.tableView = tableView

        // Add tableView to container
        containerView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        // Add scroll-to-bottom button
        let scrollToBottomButton = addScrollToBottomButton(context: context)
        context.coordinator.scrollToBottomButton = scrollToBottomButton
        containerView.addSubview(scrollToBottomButton)

        NSLayoutConstraint.activate([
            scrollToBottomButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            scrollToBottomButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15),
        ])

        return containerView
    }

    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let tableView = context.coordinator.tableView else { return }
        
        if tableView.numberOfRows(inSection: 0) != chatViewModel.chatHistory.count {
            tableView.reloadData()
        }
        
        //scrolling to the bottom on fist view update
        let lastRow = chatViewModel.chatHistory.count - 1
        guard lastRow >= 0 else { return }
        let indexPath = IndexPath(row: lastRow, section: 0)
        DispatchQueue.main.async {
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
        }
    }
    
    func addScrollToBottomButton(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(
            UIImage(
                systemName: "arrow.down",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            ),
            for: .normal
        )
        button.tintColor = UIColor(Color.textPrimary)

        // Styling
        button.backgroundColor = UIColor(Color.accent)
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.clipsToBounds = false
        button.isHidden = true

        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.addTarget(context.coordinator, action: #selector(context.coordinator.scrollToBottomAction), for: .primaryActionTriggered)
        return button
    }
}
