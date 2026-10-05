import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/sync_service.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});
  @override State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  String? _deviceId;
  String? _code;
  DateTime? _expires;
  bool _busy = false;
  final _codeController = TextEditingController();
  String? _status;
  bool _ok = false;

  @override void initState(){super.initState(); _load();}
  @override void dispose(){_codeController.dispose(); super.dispose();}
  Future<void> _load() async { final id=await SyncService.deviceId(); if(mounted)setState(()=>_deviceId=id); }

  Future<void> _createPairing() async {
    final c=await SyncService.newPairingCode();
    if(!mounted)return;
    setState((){_code=c;_expires=DateTime.now().add(const Duration(minutes:5));_status=null;_ok=false;});
  }

  Future<void> _share() async {
    if(_code==null){await _createPairing();}
    setState(()=>_busy=true);
    try { final path=await SyncService.exportPackageToFile(_code!); await SyncService.sharePackage(path); if(mounted)setState(()=>_status=tr('sync_share_done')); }
    catch(e){if(mounted)setState(()=>_status=tr('sync_failed'));}
    if(mounted)setState(()=>_busy=false);
  }

  Future<void> _import() async {
    final code=_codeController.text.trim();
    if(!RegExp(r'^\d{6}$').hasMatch(code)){setState(()=>_status=tr('sync_code_invalid'));return;}
    setState((){_busy=true;_status=null;});
    try {
      final r=await SyncService.importPackage(code: code);
      if(mounted)setState((){_ok=true;_status='${tr('sync_import_done')} ${r.imported}  •  ${tr('sync_skipped')} ${r.skipped}  •  ${tr('sync_conflicts')} ${r.conflicts}';});
    } catch(e){if(mounted)setState(()=>_status=tr('sync_failed'));
    } finally {if(mounted)setState(()=>_busy=false);}
  }

  @override Widget build(BuildContext context){
    return LayoutBuilder(builder:(context,c)=>SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(tr('sync_title'),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,color:C.navy)),
      const SizedBox(height:6), Text(tr('sync_subtitle'),style:TextStyle(color:Colors.grey.shade700)),
      const SizedBox(height:20),
      Wrap(spacing:16,runSpacing:16,children:[
        SizedBox(width:c.maxWidth>700?530:c.maxWidth,child:_card(context,Icons.qr_code_2,tr('sync_send_title'),tr('sync_send_sub'),_sendPanel(context))),
        SizedBox(width:c.maxWidth>700?530:c.maxWidth,child:_card(context,Icons.input_rounded,tr('sync_receive_title'),tr('sync_receive_sub'),_receivePanel(context))),
      ]),
      const SizedBox(height:16), _info(context),
    ]))));
  }

  Widget _card(BuildContext context,IconData icon,String title,String sub,Widget child)=>Card(elevation:1,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:C.navy.withOpacity(.08),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:C.navy)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:3),Text(sub,style:TextStyle(color:Colors.grey.shade700,fontSize:13))]))]),
    const SizedBox(height:18),child]));

  Widget _sendPanel(BuildContext context)=>Column(children:[
    Row(children:[Expanded(child:Text('${tr('sync_device_id')}: ${_deviceId??'…'}',style:const TextStyle(fontSize:12))),IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    const SizedBox(height:8),
    if(_code!=null) Center(child:Column(children:[QrImageView(data:'MFUKO-SYNC|$_code|${_deviceId??''}',size:180),const SizedBox(height:8),Text(_code!,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,letterSpacing:5)),if(_expires!=null)Text('${tr('sync_expires')}: ${_expires!.hour.toString().padLeft(2,'0')}:${_expires!.minute.toString().padLeft(2,'0')}',style:TextStyle(color:Colors.grey.shade700))]))
    else Text(tr('sync_no_code'),style:TextStyle(color:Colors.grey.shade700)),
    const SizedBox(height:14),
    Wrap(spacing:10,runSpacing:10,children:[OutlinedButton.icon(onPressed:_busy?null:_createPairing,icon:const Icon(Icons.key),label:Text(tr('sync_new_code'))),ElevatedButton.icon(onPressed:_busy?null:_share,icon:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.share),label:Text(tr('sync_share_package')))])
  ]);

  Widget _receivePanel(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    TextField(controller:_codeController,keyboardType:TextInputType.number,maxLength:6,decoration:InputDecoration(labelText:tr('sync_enter_code'),hintText:'123456',prefixIcon:const Icon(Icons.password),border:const OutlineInputBorder())),
    const SizedBox(height:8),
    Text(tr('sync_receive_hint'),style:TextStyle(color:Colors.grey.shade700,fontSize:13)),
    const SizedBox(height:14),
    SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:_busy?null:_import,icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.sync),label:Text(tr('sync_import_merge')))),
    if(_status!=null) Padding(padding:const EdgeInsets.only(top:12),child:Text(_status!,style:TextStyle(color:_ok?Colors.green.shade700:Colors.red.shade700,fontWeight:FontWeight.w600)))
  ]);

  Widget _info(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:C.navy.withOpacity(.045),borderRadius:BorderRadius.circular(16),border:Border.all(color:C.navy.withOpacity(.1))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(tr('sync_security_title'),style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),
    Text(tr('sync_security_body'),style:TextStyle(color:Colors.grey.shade800,height:1.45)),const SizedBox(height:10),
    Row(children:[const Icon(Icons.verified_user_outlined,size:18,color:C.teal),const SizedBox(width:8),Expanded(child:Text(tr('sync_local_first'),style:const TextStyle(fontWeight:FontWeight.w700)))]),
  ]));
}
