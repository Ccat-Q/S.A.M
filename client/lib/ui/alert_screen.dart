import 'package:flutter/material.dart';
import '../state/system_store.dart';
import 'instruments.dart';
import 'station.dart';
import 'theme.dart';

class AlertsScreen extends StatefulWidget{
  final SystemStore store;
  final ValueChanged<String> locate,camera,inspect,logs;
  const AlertsScreen({super.key,required this.store,required this.locate,required this.camera,required this.inspect,required this.logs});
  @override
  State<AlertsScreen> createState()=>_AlertsScreenState();
}
class _AlertsScreenState extends State<AlertsScreen>{
  bool history=false;String? selected;
  @override
  Widget build(BuildContext context){
    final store=widget.store;
    final alerts=store.alerts.where((a)=>history||a['state']!='RESOLVED').toList()
      ..sort((a,b)=>(a['severity']=='CRITICAL' ? 0 : 1).compareTo(b['severity']=='CRITICAL' ? 0 : 1));
    final alert=alerts.isEmpty ? null : alerts.firstWhere((a)=>a['id']==selected,orElse:()=>alerts.first);
    final node=alert==null ? null : store.nodes[alert['node_id']];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,20,8,8),child:Row(children:[
        const Expanded(child:Text('SYSTEM / ANOMALY ANALYSIS',style:TextStyle(fontFamily:'RobotoCondensed',fontSize:15,letterSpacing:2))),
        SoftKey(label:history ? 'ACTIVE' : 'HISTORY',onPressed:()=>setState(()=>history=!history)),
      ])),
      if(alert==null)const Expanded(child:Center(child:Text('SYS ALERT / 00\nALL CONDITIONS NOMINAL',textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:11,letterSpacing:2,height:2))))
      else Expanded(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,18,18,12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(children:[for(var i=0;i<alerts.length;i++)SoftKey(key:ValueKey('alert-${alerts[i]['id']}'),code:(i+1).toString().padLeft(2,'0'),label:alerts[i]['severity'] as String,
          selected:alerts[i]['id']==alert['id'],color:statusColor(alerts[i]['severity'] as String),onPressed:()=>setState(()=>selected=alerts[i]['id'] as String))]),
        const SizedBox(height:30),Text('SYS ALERT / ${(alerts.indexOf(alert)+1).toString().padLeft(2,'0')}',style:const TextStyle(color:muted,fontSize:10,letterSpacing:2)),
        const SizedBox(height:12),Text((alert['condition'] as String).replaceAll('_',' '),style:TextStyle(fontFamily:'RobotoCondensed',fontSize:28,letterSpacing:2,color:statusColor(alert['severity'] as String))),
        const SizedBox(height:20),Text('${node?.module ?? 'UNKNOWN'} / ${alert['node_id']}',style:const TextStyle(fontSize:13,letterSpacing:1.5)),
        const SizedBox(height:40),SizedBox(height:180,width:double.infinity,child:CustomPaint(painter:_FaultPath(store:store,nodeId:alert['node_id'] as String))),
        Reading('STATE',alert['state'] as String),Reading('OPERATOR',alert['acknowledged_by'] as String? ?? 'UNASSIGNED'),
        Text(alert['created_at'] as String,style:const TextStyle(color:muted,fontSize:8)),
        const SizedBox(height:20),const Text('ACK ≠ RESOLVE / CONDITION-DRIVEN RECOVERY',style:TextStyle(color:muted,fontSize:8)),
        const Divider(height:28),Wrap(children:[
          SoftKey(key:ValueKey('locate-${alert['node_id']}'),code:'01',label:'LOCATE',onPressed:()=>widget.locate(alert['node_id'] as String)),
          SoftKey(code:'02',label:'CAM',onPressed:()=>widget.camera(alert['node_id'] as String)),
          SoftKey(key:ValueKey('alert-link-${alert['node_id']}'),code:'03',label:'SYSTEM LINK',onPressed:()=>widget.inspect(alert['node_id'] as String)),
          SoftKey(code:'04',label:'EVENT',onPressed:()=>widget.logs(alert['node_id'] as String)),
          if(alert['state']=='ACTIVE')SoftKey(label:'ACKNOWLEDGE',onPressed:store.canControl&&store.connected ? ()=>report(context,()=>store.acknowledge(alert['id'] as String)) : null),
        ]),
      ]))),
    ]);
  }
}
class _FaultPath extends CustomPainter{
  final SystemStore store;final String nodeId;
  _FaultPath({required this.store,required this.nodeId});
  @override
  void paint(Canvas canvas,Size size){
    final origin=Offset(32,size.height*.4);
    final targets=store.edges.where((e)=>e['source']==nodeId).map((e)=>e['target'] as String).toSet().take(5).toList();
    final pen=Paint()..color=critical.withValues(alpha:.6)..strokeWidth=.8..style=PaintingStyle.stroke;
    canvas.drawCircle(origin,9,pen);drawLabel(canvas,nodeId,origin+const Offset(-15,22),critical,size:10);
    drawLabel(canvas,'FAULT SOURCE',const Offset(0,0),muted,size:8);
    for(var i=0;i<targets.length;i++){
      final p=Offset(size.width*.64,22+i*29);
      final path=Path()..moveTo(origin.dx,origin.dy)..lineTo(size.width*.32,origin.dy)..lineTo(size.width*.32,p.dy)..lineTo(p.dx,p.dy);
      canvas.drawPath(path,pen);canvas.drawCircle(p,3,Paint()..color=statusColor(store.nodes[targets[i]]?.status ?? 'UNKNOWN'));
      drawLabel(canvas,targets[i],p+const Offset(9,-5),muted,size:9);
    }
    if(targets.isEmpty)drawLabel(canvas,'LOCAL CONDITION / NO DOWNSTREAM PATH',const Offset(70,65),muted,size:9);
  }
  @override
  bool shouldRepaint(covariant _FaultPath oldDelegate)=>true;
}
