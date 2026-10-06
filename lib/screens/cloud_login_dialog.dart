import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../core/auth.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud_service.dart';

class CloudLoginDialog extends StatefulWidget {
  const CloudLoginDialog({super.key});
  @override State<CloudLoginDialog> createState() => _CloudLoginDialogState();
}

class _CloudLoginDialogState extends State<CloudLoginDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) { setState(()=>error=tr('cloud_login_invalid')); return; }
    setState(()=>busy=true);
    try {
      await CloudService.signIn(email: email.text, password: password.text);
      final role = await CloudService.currentRole();
      if (role == null) {
        await CloudService.signOut();
        if (mounted) setState(()=>error=tr('cloud_no_access'));
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (_) {
      if (mounted) setState(()=>error=tr('cloud_login_failed'));
    } catch (_) {
      if (mounted) setState(()=>error=tr('cloud_network_error'));
    } finally { if (mounted) setState(()=>busy=false); }
  }

  @override Widget build(BuildContext context)=>AlertDialog(
    title: Row(children:[const Icon(Icons.cloud_done,color:C.teal),const SizedBox(width:10),Expanded(child:Text(tr('cloud_login_title')))]),
    content: SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(tr('cloud_login_sub'),style:const TextStyle(color:C.muted)), const SizedBox(height:16),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:InputDecoration(labelText:tr('cloud_email'),prefixIcon:const Icon(Icons.email_outlined))),
      const SizedBox(height:12), TextField(controller:password,obscureText:true,decoration:InputDecoration(labelText:tr('cloud_password'),prefixIcon:const Icon(Icons.lock_outline)),onSubmitted:(_)=>submit()),
      if(error!=null) Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red))),
    ])),
    actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:Text(tr('cancel'))),ElevatedButton.icon(onPressed:busy?null:submit,icon:busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.login),label:Text(tr('login')))]
  );
}
