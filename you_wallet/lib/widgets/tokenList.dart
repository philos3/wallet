import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youwallet/model/token.dart';
import 'package:youwallet/model/viewModel.dart';
import 'package:youwallet/widgets/listEmpty.dart';
import 'package:youwallet/widgets/tokenCard.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:youwallet/widgets/customButton.dart';

// 类的名字需要大写字母开头
class tokenList extends StatefulWidget {
  List arr = [];
  String network = "ropsten";
  Map currentWalletObject = {};
  tokenList(
      {Key key, this.arr, this.network = "ropsten", this.currentWalletObject})
      : super(key: key);

  @override
  State<tokenList> createState() => _tokenListState();
}

class _tokenListState extends State<tokenList> with TickerProviderStateMixin{



  // final SlidableController slidableController = SlidableController(this);

  @override
  Widget build(BuildContext context) {
    List filterArr = [];
    widget.arr.forEach((element) {
      // 必须当前你选择的网络和当前你的钱包地址
      if (element['wallet'] == widget.currentWalletObject['address']) {
        filterArr.add(element);
      }
    });
    // 没有token则显示添加token的
    if (filterArr != null && filterArr.length == 0) {
      return Column(
        children: <Widget>[
          ListEmpty(),
          new CustomButton(
              content: '添加token',
              onSuccessChooseEvent: (res) async {
                Navigator.pushNamed(context, "add_token", arguments: {});
              })
        ],
      );
    } else {
      return Column(
        children: filterArr.reversed
            .map((item) => buildSilde(item, context))
            .toList(),
      );
    }
  }

  // 给数据列表中的每一个项包裹一层滑动组件
  Widget buildSilde(item, context) {
    TokenCardViewModel cardData = TokenCardViewModel(
      bankName: item['name'],
      bankLogoUrl: 'assets/images/icon.png',
      cardType: '以太坊',
      cardNumber: item['address'],
      cardColors: [Color(0xFFF17B68), Color(0xFFE95F66)],
      balance: item['balance'],
    );
    return Slidable(
      // controller: slidableController,
      // actionPane: SlidableScrollActionPane(), //滑出选项的面板 动画
      child: TokenCard(data: cardData),
      startActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        dismissible: DismissiblePane(onDismissed: () {}),
        children:  [
          //右侧按钮列表
          SlidableAction(
            label: '删除',
            // color: Color(0xfff56c6c),
            icon: Icons.delete,
            onPressed: (BuildContext context)  async {
              await Provider.of<Token>(context).remove(item);
            },
          )
        ],
      ),
    );
  }
}
