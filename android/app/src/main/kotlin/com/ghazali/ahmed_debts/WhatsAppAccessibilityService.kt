package com.ghazali.ahmed_debts

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class WhatsAppAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "WhatsAppService"
        var instance: WhatsAppAccessibilityService? = null
        var pendingMessage: String? = null
        var pendingPhone: String? = null
        var isWaitingForWhatsApp = false
        
        fun sendMessage(phone: String, message: String): Boolean {
            pendingPhone = phone
            pendingMessage = message
            isWaitingForWhatsApp = true
            
            // Open WhatsApp with the URL
            val formattedPhone = formatPhoneNumber(phone)
            val url = "https://wa.me/$formattedPhone?text=${Uri.encode(message)}"
            
            instance?.let { service ->
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                service.startActivity(intent)
                return true
            }
            return false
        }
        
        private fun formatPhoneNumber(phone: String): String {
            var formatted = phone.replace(Regex("[^0-9]"), "")
            if (formatted.startsWith("0")) {
                formatted = formatted.substring(1)
            }
            if (!formatted.startsWith("964")) {
                formatted = "964$formatted"
            }
            return formatted
        }
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var retryCount = 0
    private val maxRetries = 10
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service Connected")
        
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        info.notificationTimeout = 100
        info.packageNames = arrayOf("com.whatsapp")
        serviceInfo = info
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isWaitingForWhatsApp || event == null) return
        
        val packageName = event.packageName?.toString() ?: return
        if (packageName != "com.whatsapp") return
        
        Log.d(TAG, "WhatsApp event: ${event.eventType}")
        
        // Wait a bit for the UI to load
        handler.postDelayed({
            tryToClickSend()
        }, 500)
    }
    
    private fun tryToClickSend() {
        if (!isWaitingForWhatsApp) return
        
        val rootNode = rootInActiveWindow ?: return
        
        // Try to find and click the send button
        val sendButton = findSendButton(rootNode)
        
        if (sendButton != null) {
            Log.d(TAG, "Found send button, clicking...")
            sendButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            
            // Reset state after successful send
            handler.postDelayed({
                isWaitingForWhatsApp = false
                pendingMessage = null
                pendingPhone = null
                retryCount = 0
                
                // Go back to our app
                performGlobalAction(GLOBAL_ACTION_BACK)
                handler.postDelayed({
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }, 300)
            }, 500)
        } else {
            // Retry if not found yet
            retryCount++
            if (retryCount < maxRetries) {
                Log.d(TAG, "Send button not found, retrying... ($retryCount/$maxRetries)")
                handler.postDelayed({
                    tryToClickSend()
                }, 500)
            } else {
                Log.d(TAG, "Max retries reached, giving up")
                isWaitingForWhatsApp = false
                retryCount = 0
            }
        }
        
        rootNode.recycle()
    }
    
    private fun findSendButton(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // Try different ways to find the send button
        
        // Method 1: By resource ID
        val byId = node.findAccessibilityNodeInfosByViewId("com.whatsapp:id/send")
        if (byId.isNotEmpty()) {
            return byId[0]
        }
        
        // Method 2: By content description
        val byDesc = node.findAccessibilityNodeInfosByText("Send")
        for (n in byDesc) {
            if (n.isClickable) {
                return n
            }
        }
        
        // Method 3: Look for ImageButton that might be send
        return findNodeByClassName(node, "android.widget.ImageButton")
    }
    
    private fun findNodeByClassName(node: AccessibilityNodeInfo, className: String): AccessibilityNodeInfo? {
        if (node.className?.toString() == className && node.isClickable) {
            // Check if this might be the send button (usually on the right side)
            val rect = android.graphics.Rect()
            node.getBoundsInScreen(rect)
            val screenWidth = resources.displayMetrics.widthPixels
            if (rect.right > screenWidth * 0.7) { // On the right side of screen
                return node
            }
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findNodeByClassName(child, className)
            if (result != null) {
                return result
            }
        }
        
        return null
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "Accessibility Service Destroyed")
    }
}
