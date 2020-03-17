import 'package:flutter/material.dart';
import 'package:common_utils/common_utils.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:youwallet/widgets/modalDialog.dart';
import 'package:youwallet/widgets/loadingDialog.dart';
import 'package:provider/provider.dart';
import 'package:youwallet/model/deal.dart';
import 'package:youwallet/bus.dart';
import 'package:provider/provider.dart';
import 'package:youwallet/model/deal.dart';
import 'package:youwallet/service/trade.dart';
import 'package:flutter/services.dart';

class transferList extends StatefulWidget {

//  List arr = [];
//  Map filledAmount = {};

  transferList({Key key}) : super(key: key);

  Page createState() => new Page();
}

class Page extends State<transferList> {

  final SlidableController slidableController = SlidableController();
  List arr = []; // 控制当前页面中显示的兑换数组
  Map filledAmount = {};

  //数据初始化
  @override
  void initState() {
    super.initState();

    /// tab切换
    eventBus.on<CustomTabChangeEvent>().listen((event) {
      print('change in component');
      this.tabChange(event.res);
    });

    /// 用户挂单成功，拿到刚刚挂的订单Hash，查询订单是否成功
    eventBus.on<OrderSuccessEvent>().listen((event) {
      this.tabChange('当前兑换');
      this.updateOrderStatus();
    });

    /// 监听兑换页面用户手动触发下拉刷新
    eventBus.on<UpdateOrderListEvent>().listen((event) {
      this.updateOrderFilled();
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
//    List list = await Provider.of<Deal>(context).getTraderList();
//    setState(() {
//      this.arr = List.from(list);
//    });
//      this.tabChange('当前兑换');
  }


  @override
  Widget build(BuildContext context) {
    return new Container(
        padding: const EdgeInsets.only(bottom: 12.0), // 四周填充边距32像素
        child: new Column(
          children: this.arr.reversed.map((item) => buildsilde(item, context)).toList()
        )
    );
  }

  // 给数据列表中的每一个项包裹一层滑动组件
  Widget buildsilde(item, context) {
    return Slidable(
      controller: slidableController,
      actionPane: SlidableScrollActionPane(),//滑出选项的面板 动画
      actionExtentRatio: 0.25,
      child: this.buildItem(item, context),
      secondaryActions: <Widget>[//右侧按钮列表
        IconSlideAction(
          caption: '订单详情',
          color: Colors.blue,
          icon: Icons.assignment,
          onTap: () {
            //print(item);
            //this.copyHash(item);
            Navigator.pushNamed(context, "order_detail", arguments: item);
          },
        ),
        this.buildRightAction(context, item)
      ],
    );
  }

  // 构建滑动后右侧出现的小部件
  Widget buildRightAction(context, item){
    if (item['status'] == '转账中' || item['status'] == '进行中' || item['status'] == '') {
      return IconSlideAction(
        caption: '撤销',
        color: Colors.red,
        icon: Icons.undo,
        closeOnTap: true,
        onTap: () {
          this.cancelTrade(context, item);
        },
      );
    } else {
      return IconSlideAction(
        caption: '删除',
        color: Colors.red,
        icon: Icons.delete,
        closeOnTap: true,
        onTap: () {
          this.delTrade(context, item);
        },
      );
    }
  }


  Widget buildItem(item, context) {
//    print(item);
    String date = DateUtil.formatDateMs( int.parse( item['createTime']), format: DataFormats.full);
    String filled = '';
    if (item['status'] == '成功'){
      filled = item['filled'];
    } else {
      filled = this.filledAmount.containsKey(item['txnHash'])?this.filledAmount[item['txnHash'].toString()]:item['filled'];
    }
    return new Container(
        padding: const EdgeInsets.only(top:10.0, bottom: 10.0), // 四周填充边距32像素
        decoration: new BoxDecoration(
           border: Border(bottom: BorderSide(color: Colors.black26,width: 1.0)),
//           color: Colors.lightBlue,
        ),
        child: new Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  new Row(
                    children: <Widget>[
                      new Text(
                          '${item['orderType']}',
                          style: new TextStyle(
                              color: item['orderType']== '买入' ? Colors.green : Colors.deepOrange
                          )
                      ),
                      new Text('   ${date}'),
                    ],
                  ),
                  new Text(
                      item['status']??'进行中',
                      style: new TextStyle(
                          color: Colors.deepOrange
                      )
                  )
                ],
              ),
              new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  new Text(
                      '${item['price']} (${item['baseTokenName']})',
                  ),
                  new Text(
                      '${filled.toString()}/${item['amount']}(${item['tokenName']})',
                      style: new TextStyle(
                          color: Colors.lightBlue
                      )
                  )
                ],
              ),
            ],
      )
    );

  }

  // 取消交易
  void cancelTrade(BuildContext context, Map item){
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return GenderChooseDialog(
              title: '确定撤销交易?',
              content: '',
              onSuccessChooseEvent: () async {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "getPassword").then((data) async{
                      this.cancelProcess(item, data);
                  });
              },
              onCancelChooseEvent: () {
                Navigator.pop(context);
              });

        });
  }

  // 取消订单的进程，不会立刻拿到结果
  void cancelProcess(Map item, String pwd) async{
    showDialog<Null>(
        context: context, //BuildContext对象
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new LoadingDialog( //调用对话框
            text: '撤销中...',
          );
        }
    );
    String res = await Trade.cancelOrder2(item, pwd);
    print('订单撤销返回 => ${res}');
    String orderFlag = await Trade.orderFlag(item);
    int resOrder = int.parse(orderFlag.replaceFirst("0x",''), radix: 16);
    print(resOrder);
    if (resOrder == 0) {
      await Provider.of<Deal>(context).updateOrderStatus(item['txnHash'], '交易撤销');
      this.updateList();
      eventBus.fire(TransferDoneEvent('撤销成功成功'));
    } else {
      eventBus.fire(TransferDoneEvent('撤销失败，订单状态当前为挂单中'));
    }

  }

  // 删除历史记录
  void delTrade(BuildContext context, Map item){
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return GenderChooseDialog(
              title: '确定删除记录?',
              content: '',
              onSuccessChooseEvent: () async {
                int i = await Provider.of<Deal>(context).deleteTrader(item['id']);
                // 用bus向兑换页面发出删除成功的通知，兑换页面显示toast
                if (i == 1) {
                  this.arr.removeWhere((element) => element['id']==item['id']);
                  setState(() {
                    this.arr;
                  });
                  eventBus.fire(TransferDoneEvent('删除成功'));
                }
              });
        });
  }

  // tab切换, 切换显示的数据，这里不刷新
  // 这里list需要用List.from转化一次，否则会提示read only
  void tabChange(String tab) async {
    List list = List.from(await Provider.of<Deal>(context).getTraderList());
//    int now = DateTime.now().millisecondsSinceEpoch;
//    int hour = DateTime.now().hour;
//    int minute = DateTime.now().minute;
//    int second = DateTime.now().second;
//    int today = now - (hour*60*60 + minute*60 + second)*1000;

    if (tab == '当前兑换') {
      print('here tab is => ${tab}');
      list.retainWhere((element)=>(element['status']=='进行中' || element['status']=='打包中' ));
//      this._getTradeInfo(list);
    } else {
      list.retainWhere((element)=>(element['status']!='进行中'));
    }
    setState(() {
      this.arr = list;
    });
//    this.updateOrderStatus();
  }

  /// 遍历每个订单的状态
  /// 将查询到的匹配数量保存在数据库中
  /// 如果订单中的数量已经匹配完毕，则代表这个订单转账成功，刷新的时候不再遍历
  /// 两个失败的订单
  ///
  Future<void> updateOrderFilled() async {
    List list = List.from(await Provider.of<Deal>(context).getTraderList());
    list.retainWhere((element)=>(element['status']=='进行中'|| element['status']=='打包中'));
    Map filled = {};
    for(var i = list.length -1; i>=0; i--) {
      //print('查询订单   =》${this.arr[i]['txnHash']}');
      if(list[i]['status'] == '进行中' || list[i]['status'] == '打包中') {
        double amount = await Trade.getFilled(list[i]['odHash']);
        print('匹配情况   =》${list[i]['status']}-${amount}');
        await Provider.of<Deal>(context).updateFilled(
            list[i], amount.toStringAsFixed(2));
        filled[list[i]['txnHash']] = amount.toStringAsFixed(2);
        Map res = await Trade.getTransactionReceipt(list[i]);
        print('根据凭据查询');
        print(res);
        print(res['root']);
        print(res['status']);
      } else {
        //print('该订单状态为${this.arr[i]['status']},已匹配完毕');
      }
    }
    setState(() {
      this.filledAmount = filled;
    });
//    print(this.filledAmount);
    this.updateList();
    eventBus.fire(TransferDoneEvent('订单刷新完毕'));
  }

  /// 订单匹配状态查询完毕，整体更新一次列表
  void updateList() async {
    List list = List.from(await Provider.of<Deal>(context).getTraderList());
    list.retainWhere((element)=>(element['status']=='进行中' || element['status']=='打包中' ));
    setState(() {
      this.arr = list;
    });
  }

  /// 点击订单复制订单的hash
  void copyHash(Map item) {
    ClipboardData data = new ClipboardData(text: item['txnHash']);
    Clipboard.setData(data);
    eventBus.fire(TransferDoneEvent('订单复制成功'));
  }

  /// 拿到订单列表中最新的一个订单状态为打包中的订单，查询订单状态
  void updateOrderStatus() async {
    List list = await Provider.of<Deal>(context).getTraderList();
    Map order = list.lastWhere((e)=>e['status'] == '打包中',orElse: ()=>(null));
    if (order == null) {
      print('no order');
      return;
    } else {
      this.checkOrderStatus(order['txnHash'], 0);
    }
  }

  void checkOrderStatus(String hash, int index) async {
    Map response = await Trade.getTransactionByHash(hash);
    print("第${index}次查询");
    print(response);
    if(response['blockHash'] != null) {
      print('打包成功，以太坊返回了交易的blockHash');
      await Provider.of<Deal>(context).updateOrderStatus(hash, '进行中');
      this.updateList();
      eventBus.fire(TransferDoneEvent('打包成功，订单状态变更为进行中'));
    } else {
      if (index > 30) {
        print('已经轮询了30次，打包失败');
        eventBus.fire(TransferDoneEvent('订单打包超时，请重新下单'));
      } else {
        Future.delayed(Duration(seconds: 2), (){
          this.checkOrderStatus(hash, index+1);
        });
      }
    }
  }

}