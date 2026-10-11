import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Kitufe cha Kiswahili / English - kinaonekana kila page juu kulia.
class LangToggle extends StatelessWidget {
  final bool onDark;
  const LangToggle({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) {
        final cur = L10n.instance.lang;
        final phone = MediaQuery.sizeOf(context).width < 600;
        Widget chip(String code, String label) {
          final sel = cur == code;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => L10n.instance.setLang(code),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: phone ? 9 : 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? C.activeStart : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? Colors.white : (onDark ? Colors.white70 : C.text),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: onDark ? Colors.white30 : C.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!phone)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 2),
                  child: Icon(Icons.language,
                      size: 17, color: onDark ? Colors.white70 : C.muted),
                ),
              chip('sw', phone ? 'SW' : 'Kiswahili'),
              chip('en', phone ? 'EN' : 'English'),
            ],
          ),
        );
      },
    );
  }
}
