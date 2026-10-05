import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/cloud_service.dart';
import '../services/sync_service.dart';
import 'cloud_login_dialog.dart';

class SyncPage extends StatefulWidget { const SyncPage({super.key}); @override State<SyncPage> createState()=>_SyncPageState(); }
class _SyncPageState extends State<SyncPage> {
  bool busy=false; String? status; bool ok=false; String? device;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async { final d=await SyncService.deviceId(); if(mounted)setState(()=>device=d); }
  Future<void> _login() async { if(!CloudService.available){setState(()=>status=CloudService.missingMessage());return;} final r=await showDialog<bool>(context:context,builder:(_)=>const CloudLoginDialog()); if(r==true&&mounted)setState(()=>status=tr('cloud_login_done')); }
  Future<void> _sync() async {
    if(!CloudService.available){setState(()=>status=CloudService.missingMessage());return;}
    if(CloudService.user==null){await _login(); if(CloudService.user==null)return;}
    setState(() { busy=true; status=null; ok=false; });
    try { final r=await CloudService.sync(); if(mounted)setState(() { ok=true; status='${tr('cloud_sync_done')} ${tr('cloud_uploaded')} ${r.uploaded} • ${tr('cloud_downloaded')} ${r.downloaded} • ${tr('cloud_conflicts')} ${r.conflicts}'; }); }
    catch(e){if(mounted)setState(()=>status=e.toString().contains('NO_CHURCH_ACCESS')?tr('cloud_no_access'):tr('cloud_sync_failed'));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _logout() async { await CloudService.signOut(); if(mounted)setState(()=>status=tr('cloud_logged_out')); }
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:950),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(tr('sync_title'),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,color:C.navy)),
    const SizedBox(height:6),Text(tr('sync_subtitle'),style:const TextStyle(color:C.muted)),const SizedBox(height:20),
    Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:C.teal.withOpacity(.10),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.cloud_sync_rounded,color:C.teal,size:28)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr('cloud_sync_title'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(tr('cloud_sync_sub'),style:const TextStyle(color:C.muted))]))]),
      const SizedBox(height:20),
      _row(Icons.person_outline,tr('cloud_account'),CloudService.user?.email??tr('cloud_not_connected')),
      _row(Icons.devices_outlined,tr('sync_device_id'),device??'…'),
      const SizedBox(height:12),
      Wrap(spacing:10,runSpacing:10,children:[
        if(CloudService.user==null) ElevatedButton.icon(onPressed:busy?null:_login,icon:const Icon(Icons.login),label:Text(tr('cloud_login')))
        else ...[ElevatedButton.icon(onPressed:busy?null:_sync,icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.sync),label:Text(tr('cloud_sync_now'))),OutlinedButton.icon(onPressed:busy?null:_logout,icon:const Icon(Icons.logout),label:Text(tr('cloud_logout')))],
      ]),
      if(status!=null) Padding(padding:const EdgeInsets.only(top:16),child:Text(status!,style:TextStyle(color:ok?Colors.green.shade700:Colors.red.shade700,fontWeight:FontWeight.w700))),
    ]))),const SizedBox(height:16),
    Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:C.navy.withOpacity(.045),borderRadius:BorderRadius.circular(16),border:Border.all(color:C.navy.withOpacity(.10))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr('cloud_security_title'),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(tr('cloud_security_body'),style:const TextStyle(color:C.text,height:1.5)),const SizedBox(height:8),Text(tr('sync_local_first'),style:const TextStyle(fontWeight:FontWeight.w700,color:C.teal))]))
  ]))));
  Widget _row(IconData i,String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Icon(i,size:20,color:C.muted),const SizedBox(width:10),SizedBox(width:125,child:Text(a,style:const TextStyle(fontWeight:FontWeight.w700))),Expanded(child:Text(b))]));
}
