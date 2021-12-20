import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memorize/data.dart';
import 'package:memorize/widget.dart';

class ATab {
  ATab({required Icon icon, required Widget child, bool isMain = false})
      : _icon = icon,
        tabIcon = isMain ? const Icon(Icons.home) : icon,
        tab = child,
        bMain = isMain;

  final Icon _icon;
  Icon tabIcon;
  Widget tab;
  bool bMain;
}

class CommunityTab extends StatefulWidget {
  const CommunityTab({Key? key}) : super(key: key);

  @override
  State<CommunityTab> createState() => _CommunityTab();
}

class _CommunityTab extends State<CommunityTab> {
  //final double _scrollableCategoryHeight = 100.0;
  //final double _scrollableCategoryMargin = 10.0;
  final double _scrollableCatHeight = 0.4;

  Widget _buildSearchBar() {
    return Container(
      height: 40.0,
      margin: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 30.0),
      //decoration: const BoxDecoration(color: Colors.amber),
      //child:
      //const Padding(
      //  padding: EdgeInsets.symmetric(horizontal: 80.0, vertical: 20.0),
      child: TextField(
        textAlignVertical: TextAlignVertical.bottom,
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.black54,
          ),
          hintText: "Search ...",
          hintStyle: TextStyle(
            color: AppData.colors["hintText"],
            fontSize: 20.0,
          ),
          filled: true,
          //fillColor: Color(0xFFF3F3F3),
          fillColor: AppData.colors["container"],
          border: OutlineInputBorder(
            borderSide: BorderSide(
                color: AppData.colors["border"] ?? const Color(0xFF000000),
                style: BorderStyle.solid),
            borderRadius: const BorderRadius.all(Radius.circular(5.0)),
          ),
        ),
      ),
      //),
    );
  }

  @override
  Widget build(BuildContext cxt) {
    return Column(
      children: [
        //search bar
        Expanded(
            child: ListView(
          children: [
            _buildSearchBar(),
            //Top lists
            ScrollableCategory(
                label: RichText(
                  text: TextSpan(
                      text: "Top ",
                      style: const TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      children: [
                        TextSpan(
                            text: 'lists',
                            style: TextStyle(
                                color: AppData.colors["buttonSelected"])),
                      ]),
                ),
                height:
                    MediaQuery.of(context).size.width * _scrollableCatHeight,
                onTap: (i) => print("top item $i"),
                itemBuilder: (ctx, i) {
                  return Container();
                }),

            //Recent lists
            Container(
                margin: const EdgeInsets.only(top: 40.0),
                child: ScrollableCategory(
                    label: RichText(
                      text: TextSpan(
                          text: "Recent ",
                          style: const TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'lists',
                                style: TextStyle(
                                    color: AppData.colors["buttonSelected"])),
                          ]),
                    ),
                    height: MediaQuery.of(context).size.width *
                        _scrollableCatHeight,
                    onTap: (i) => print("recent item $i"),
                    itemBuilder: (ctx, i) {
                      return Container();
                    })),
            Container(
                margin: const EdgeInsets.only(top: 40.0),
                child: ScrollableCategory(
                    label: RichText(
                      text: TextSpan(
                          text: "Place ",
                          style: const TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'holder',
                                style: TextStyle(
                                    color: AppData.colors["buttonSelected"])),
                          ]),
                    ),
                    height: MediaQuery.of(context).size.width *
                        _scrollableCatHeight,
                    onTap: (i) => print("place holder item $i"),
                    itemBuilder: (ctx, i) {
                      return Container();
                    })),
          ],
        )),
      ],
    );
  }
}

class ScrollableCategory extends StatefulWidget {
  const ScrollableCategory({
    Key? key,
    this.label,
    this.itemCount,
    required this.onTap,
    required this.height,
    required this.itemBuilder,
  }) : super(key: key);

  final RichText? label;
  final int? itemCount;
  final double height;
  final void Function(int) onTap;
  final Widget Function(BuildContext, int) itemBuilder;

  @override
  State<ScrollableCategory> createState() => _ScrollableCategory();
}

class _ScrollableCategory extends State<ScrollableCategory> {
  final double borderWidth = 2.0;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
          border: Border.symmetric(
              horizontal: BorderSide(
                  color: AppData.colors["border"] ?? const Color(0xFF000000),
                  width: borderWidth))),
      child: Column(
        children: [
          widget.label == null
              ? Container()
              : Container(
                  padding: const EdgeInsets.only(left: 10.0, top: 5.0),
                  alignment: Alignment.topLeft,
                  child: widget.label),
          SizedBox(
            height: widget.height,
            child: ListView.builder(
                //itemExtent: 1.0,
                itemCount: widget.itemCount,
                scrollDirection: Axis.horizontal,
                //itemBuilder: widget.itemBuilder
                itemBuilder: (BuildContext ctx, int i) {
                  return GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: () => widget.onTap(i),
                      child: Container(
                          margin: const EdgeInsets.all(10.0),
                          width: widget.height - 10.0,
                          decoration: BoxDecoration(
                              color: AppData.colors["container"],
                              border: Border.fromBorderSide(BorderSide(
                                  color: AppData.colors["border"] ??
                                      const Color(0xFF000000),
                                  width: borderWidth,
                                  style: BorderStyle.solid)),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(5.0))),
                          child: const Center(
                            child: Text(""),
                          )));
                }),
          ),
        ],
      ),
    );
  }
}

class ListTab extends StatefulWidget {
  const ListTab({Key? key}) : super(key: key);

  @override
  State<ListTab> createState() => _ListTab();
}

class _ListTab extends State<ListTab> {
  bool _addMenu = false;
  bool _selectable = false;
  bool _enableSelect = true;
  final List<int> _selection = [];

  bool _enableSelection() {
    bool ret = _enableSelect;
    _enableSelect = true;
    return ret;
  }

  Widget _buildAddBtns() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _addItemBtn(
          onPressed: () => setState(() {
            UserData.listData.add(AList(UserData.listData.wd, "myList"));
          }),
          child: const Icon(Icons.list),
        ),
        _addItemBtn(
            onPressed: () => setState(() {
                  UserData.listData
                      .add(ACategory(UserData.listData.wd, "myCat"));
                }),
            child: const Icon(Icons.category)),
        _addItemBtn(child: const Icon(Icons.cancel_sharp))
      ],
    );
  }

  Widget _buildSelectionBtns() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
            onPressed: () {
              setState(() {
                UserData.listData.rmAll(_selection);
                _selectable = false;
                _selection.clear();
                _enableSelect = false;
              });
            },
            child: const Icon(Icons.delete)),
        FloatingActionButton(
            onPressed: () {
              setState(() {
                _selectable = false;
                _selection.clear();
                _enableSelect = false;
              });
            },
            child: const Icon(Icons.cancel_sharp))
      ],
    );
  }

  FloatingActionButton _addItemBtn(
      {void Function()? onPressed, Widget? child}) {
    return FloatingActionButton(
        child: child,
        onPressed: () => setState(() {
              _addMenu = false;
              if (onPressed != null) {
                onPressed();
              }
            }));
  }

  @override
  Widget build(BuildContext ctx) {
    return FileExplorer(
      data: UserData.listData,
      enableSelection: _enableSelection,
      onSelection: () => setState(() {
        _selectable = true;
      }),
      onSelected: (id, value) {
        value ? _selection.add(id) : _selection.remove(id);
      },
      floatingActionButton: _addMenu
          ? _buildAddBtns()
          : (_selectable
              ? _buildSelectionBtns()
              : FloatingActionButton(
                  onPressed: () => setState(() {
                    _addMenu = true;
                  }),
                  child: const Icon(Icons.add),
                )),
    );
  }
}
