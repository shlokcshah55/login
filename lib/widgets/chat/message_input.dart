import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final FocusNode? focusNode;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: PinitColors.cream.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: PinitColors.creamDeep,
            width: 1.5,
          ),
        ),
        boxShadow: PinitColors.elevatedShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: AppTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergine,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a message',
                  hintStyle: AppTypography.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: PinitColors.mute,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          isSending
              ? Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: PinitColors.creamSunk,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PinitColors.creamDeep,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            PinitColors.aubergine),
                      ),
                    ),
                  ),
                )
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    color: PinitColors.aubergine,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PinitColors.aubergine,
                        blurRadius: 0,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _handleSend,
                    icon: const Icon(
                      FeatherIcons.arrowUp,
                      color: PinitColors.cream,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _handleSend() {
    if (controller.text.trim().isNotEmpty && !isSending) {
      onSend();
    }
  }
}
