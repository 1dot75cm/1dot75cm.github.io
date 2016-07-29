layout: post
title: MongoDB mapReduce 小坑
date: 2016-07-30 00:26:10
tags: [MongoDB]
categories: Database
---

自从用 Scrapy 抓到了淘宝数据，就想着结合 Flask 写个搜索服务，可以聚合搜索淘宝、京东等电商的商品。说干就干，几天就写了一个 Demo，见 {% link taobaobao https://github.com/1dot75cm/taobaobao/
%}。数据库使用 MongoDB，这期间遇到一个 mapReduce 的小坑。记录之～

## Map-Reduce

Map-Reduce 是一种计算模型，将大量数据分解 (Map) 执行，然后再将结果合并成最终结果 (Reduce)。MongoDB 提供{% link mapReduce https://docs.mongodb.com/manual/reference/command/mapReduce/#dbcmd.mapReduce %} 数据库命令。

## mapReduce Format

{% codeblock lang:javascript %}
db.collection.mapReduce(
  <map function>,             // 分解数据，发出键值对
  <reduce function>,          // 汇总数据
  {
    out: <collection>,        // 可输出至collection或inline
    query: <document>,        // 符合条件的文档，将传入map函数
    sort: <document>,         // 排序输入文档
    limit: <number>,          // 限制输入map函数的文档数
    finalize: <function>,     // 接收reduce函数输出，作后处理（计算平均数，裁剪数组，清除冗余）
    scope: <document>,        // 指定map, reduce, finalize函数可访问的全局变量
    jsMode: <boolean: false>, // 指定是否将map-reduce函数的中间数据转换为BSON
    verbose: <boolean: true>, // 指定是否包含定时器信息
    bypassDocumentValidation: <boolean> // 旁路文档验证可插入不符合验证要求的文档
  }
)
{% endcodeblock %}

### Example 1
{% codeblock lang:javascript %}
db.orders.mapReduce (
  function() { emit( this.cust_id, this.amount ); },   // map函数
  function(key, values) { return Array.sum( values ) }, // reduce函数
  {
    query: { status: "A" },  // 查询条件
    out: "order_totals"  // 输出至 Collection
  }
)
{% endcodeblock %}

该示例中，MongoDB 应用 map 至每个文档（匹配查询条件的文档）。map 函数发出 key-value 对。对于那些包含重复值的键，MongoDB 应用 reduce，收集/汇总聚合数据。最后，存储结果至 Collection。还可以通过 finalize 函数，进一步处理结果。

所有 map-reduce 函数都运行在 mongod 进程中的 JavaScript。Map-reduce 操作以单个 collection 中的文档作为输入，在开始 map 阶段前，可以任意执行排序和限制操作。mapReduce 可以以文档返回 map-reduce 操作的结果，也可以将结果写入 Collection。输入和输出 collection 可以被分片。

注意：对于大多聚合操作，Aggregation Pipeline 提供更好的性能和一致性。map-reduce 提供更多灵活性。

### Example 2

按 catid 分组，提取 categories 第二项作为大类，第三项作为子类。数据格式如下：

{% codeblock lang=json %}
  {'_id': ObjectId('5794d204d89717bb1a251f1b'),
  'categories': [
    {'catid': '0', 'name': '所有分类'},
    {'catid': '50065355', 'name': '五金/工具'},
    {'catid': '50065362', 'name': '刃具'},
    {'catid': '50065567', 'name': '铣刀类'},
    {'catid': '50065976', 'name': '立铣刀'} ] },
{% endcodeblock %}

需要的输出格式：
{% codeblock lang=json %}
  {'catid': '50065355', 'name': '五金/工具', 'sub':[
    {'catid': 子类1, 'name': 子类1},
    {'catid': 子类2, 'name': 子类2} ]
  },
{% endcodeblock %}

Map funcion：
{% codeblock lang:javascript %}
var map = function() {
  key = this.categories[1].catid;
  value = {
    name: this.categories[1].name,
    catid: this.categories[1].catid,
    sub: [{
      catid: this.categories[2].catid,
      name: this.categories[2].name
    }]
  }
  emit(key, value);  // 按key进行分组
}
{% endcodeblock %}

针对每个 BSON 对象应用 map 函数，emit 返回的 key 用于分组。处理过程中，如果遇到相同 key，则将 value 值 push 至临时数组；待数组达到指定大小，则传递给 reduce 的 values 进行聚合处理；reduce 返回值将再次添加至临时数组，数组达到大小，reduce 聚合处理，直至所有相同 key 的值都聚合完成，输出。
由于 reduce 需要被反复调用，所以要求 reduce 返回的文档必须能作为第二个参数的一个元素。
（之前，不了解 mapReduce 会分批处理，所以 Reduce 函数没有取到所有值，导致结果缺项。）

Reduce funcion：
{% codeblock lang:javascript %}
var reduce = function(key, values) {  // values为重复key项组成的数组
  var tmp = [];
  for (var i=0; i<values.length; i++) {
    for (var j in values[i].sub) {  // 分批迭代，sub可能包含多项子类
      var vaild = 0;
      for (var k in tmp)
        if (tmp[k].catid === values[i].sub[j].catid)
          vaild++;
          if (vaild === 0)
            tmp.push(values[i].sub[j]);
    }
  }
  return {  // 结果会返回values进行分批迭代
      name: values[0].name,
      catid: key,
      sub: tmp
  };
}
{% endcodeblock %}

执行 mapReduce 命令：
{% codeblock lang:javascript %}
var result = db.categories.mapReduce( map, reduce, { out: {'inline': 1}, finalize: final } ).find()
[ result[i].value for(i in result) ]
{% endcodeblock %}

## 参考

- {% link mapReduce reference https://docs.mongodb.com/manual/reference/command/mapReduce/#dbcmd.mapReduce %}

-- EOF --
