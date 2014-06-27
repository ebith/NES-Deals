request = require 'request'
cheerio = require 'cheerio'
iconv = require 'iconv-lite'
moment = require 'moment'
express = require 'express'
rss = require 'rss'
intl = require 'intl'
cronJob = require('cron').CronJob

deals = []
xml = []
feed = new rss title: 'ニンテンドーeショップのセール情報'
nf = new intl.NumberFormat 'ja-JP'
moment.lang 'ja'

app = do express
app.set 'view engine', 'jade'
app.get '/', (req, res) ->
  res.format
    xml: -> res.send xml
    html: -> res.render 'index', deals: deals
    json: -> res.send deals

do main = ->
  url = 'http://search1.nintendo.co.jp/search/software.php?ac=search&release[start]=0&release[end]=21&hard[2]=wiiU_dl&hard[9]=3dsDl&sales_date_type=old&limit=10000'
  request.get(url).pipe(iconv.decodeStream('shift_jis')).collect (err, body) ->
    $ = cheerio.load body
    hitCount = $('#searchResult .resultText').text().match(/\d+/)[0] - 0
    list = $('body').find('.detail') # cheerioの場合$('#ViewSearchList')だとうまくいかない。jQueryだとおｋ

    if hitCount is list.length
      list.each (i, elem) ->
        if $(elem).find('.datePrice').text().search(/→/) > 0
          deals.push
            title: $(elem).find('.title').text()
            url: $(elem).find('.title').find('a').attr('href')
            regularPrice: regularPrice = $(elem).find('.labelFont').text().match(/((\d|,)+)円/)[1].split(',').join('')
            discountPrice: discountPrice = $(elem).find('.price').text().split(',').join('')
            discountPct: discountPct = Math.round 100 - (discountPrice / regularPrice) * 100
            eta: eta = moment(("0#{v}".slice(-2) for v, k in $(elem).find('.labelFont').text().match(/～(\d{4})\.(\d{1,2})\.(\d{1,2})\s(\d{1,2}):(\d{1,2})/) when k > 0).join('-') + '+09:00', 'YY-MM-DD-HH-mmZ').format()
            etaJa: moment(eta).format 'LLL'
            description: "¥#{nf.format regularPrice} \u2192 ¥#{nf.format discountPrice} #{discountPct}%オフ"

      for deal, key in deals
        feed.items.unshift
          title: deal.title
          description: deal.description
          url: deal.url
          date: deal.eta
          categories: []
      xml = do feed.xml

do (new cronJob '0 0 */8 * * *', -> do main).start
app.listen process.env.PORT or '3000'
