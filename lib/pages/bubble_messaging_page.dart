import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_group_model.dart';
import '../providers/messaging_provider.dart';
import '../supabase/service.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/message_list.dart';

class BubbleMessagingPage extends StatefulWidget {
  final ChatGroupModel bubble;

  const BubbleMessagingPage({
    Key? key,
    required this.bubble,
  }) : super(key: key);

  @override
  State<BubbleMessagingPage> createState() => _BubbleMessagingPageState();
}

class _BubbleMessagingPageState extends State<BubbleMessagingPage> {
  late MessagingProvider _provider;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _provider = MessagingProvider(
      bubbleId: widget.bubble.id,
      messagingHelper: SupabaseService().messaging,
    );
    _provider.initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.primaryColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.bubble.groupAvatar.isNotEmpty
                    ? NetworkImage(widget.bubble.groupAvatar)
                    : null,
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                child: widget.bubble.groupAvatar.isEmpty
                    ? Icon(Icons.group, color: theme.primaryColor, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bubble.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.bubble.memberCount} members',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: theme.primaryColor),
              onPressed: () {
                // TODO: Show options menu
              },
            ),
          ],
        ),
        body: Consumer<MessagingProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.messages.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.error != null && provider.messages.isEmpty) {
              return _buildErrorState(provider);
            }

            return Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('lib/assets/messsaging_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: MessageList(
                      messages: provider.messages,
                      scrollController: _scrollController,
                      isLoadingMore: provider.isLoadingMore,
                      hasMore: provider.hasMore,
                      currentUserId: provider.currentUserId,
                      onLoadMore: () => provider.loadMoreMessages(),
                    ),
                  ),
                  MessageInput(
                    controller: _messageController,
                    focusNode: _focusNode,
                    isSending: provider.isSending,
                    onSend: _handleSendMessage,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(MessagingProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load messages',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.loadMessages(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSendMessage() async {
    final content = _messageController.text;
    if (content.trim().isEmpty) return;

    _messageController.clear();

    final success = await _provider.sendMessage(content);

    if (success) {
      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }
}
