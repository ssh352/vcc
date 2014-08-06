\l json.k
\c 30 120
quote:([]time:`time$();sym:`$();exch:`$();bpx:`float$();apx:`float$();bsz:`float$();asz:`float$();bprcs:();aprcs:();bszs:();aszs:();bnm:();anm:();timestamp:`timestamp$();exchtm:`timestamp$());
maxamt:100000;
valatrisk:10000;
exchl:`bitstamp`bitfinex`hitbtc`btce`lakebtc`itbit`kraken`okcoin
newexchl:enlist `coinsetter;
exchurl:exchl!(`$"https://www.bitstamp.net/api/order_book/";`$"https://api.bitfinex.com/v1/book/btcusd";`$"http://api.hitbtc.com/api/1/public/BTCUSD/orderbook";`$"https://btc-e.com/api/2/btc_usd/depth";`$"https://www.lakebtc.com/api_v1/bcorderbook";`$"https://www.itbit.com/api/v2/markets/XBTUSD/orders/";`$"https://api.kraken.com/0/public/Depth?pair=XBTUSD";`$"https://www.okcoin.com/api/depth.do?ok=1");
newexchurl:newexchl!(`$"https://api.coinsetter.com/v1/marketdata/depth?depth=MAX&format=LIST&exchange=COINSETTER");
quoteupsrt:{[exch;bprcs;bszs;aprcs;aszs;exchtm]
	blmt:((count accumval)-(count accumval where (accumval:(+) scan (*) .' (bprcs ,' bszs))>maxamt));
	bpx:first bprcs;bsz:first bszs;
	almt:((count accumval)-(count accumval where (accumval:(+) scan (*) .' (aprcs ,' aszs))>maxamt));
	apx:first aprcs;asz:first aszs;
	`quote upsert (.z.T;`BTCUSD;exch;bpx;apx;bsz;asz;blmt#bprcs;almt#aprcs;blmt#bszs;almt#aszs;();();.z.P;exchtm);
	}
parseq1:{[exch;d]
	bidl:flip "F"$d`bids;
	bprcs:bidl 0; bszs:bidl 1;
	offerl:flip "F"$d`asks;
	aprcs:offerl 0; aszs:offerl 1;
	quoteupsrt[exch;bprcs;bszs;aprcs;aszs;.z.P];
	}
bitstamp:parseq1[`bitstamp];
hitbtc:parseq1[`hitbtc];
itbit:parseq1[`itbit];
bitfinex:{[d]
	bprcs:"F"$(d`bids)`price;
	bszs:"F"$(d`bids)`amount;
	aprcs:"F"$(d`asks)`price;
	aszs:"F"$(d`asks)`amount;
	quoteupsrt[`bitfinex;bprcs;bszs;aprcs;aszs;.z.P];
	}
parseq2:{[exch;d]
	bidl:flip d`bids;
	bprcs:bidl 0; bszs:bidl 1;
	offerl:flip d`asks;
	aprcs:offerl 0; aszs:offerl 1;
	quoteupsrt[exch;bprcs;bszs;aprcs;aszs;.z.P];
	}
btce:parseq2[`btce];
lakebtc:parseq2[`lakebtc];
kraken:{[d]
	bprcs:bszs:aprcs:aszs:enlist 0n;
	if[count d;
	   bprcs:"F"$(bl:flip raze (value (d`result))`bids) 0;
	   bszs:"F"$bl 1;
	   aprcs:"F"$(al:flip raze (value (d`result))`asks) 0;
	   aszs:"F"$al 1;
	];
   quoteupsrt[`kraken;bprcs;bszs;aprcs;aszs;.z.P];
	}
okcoin:parseq2[`okcoin];

getmktandarbs:{[]getmktdata[]; getarbs[1000f;tm:last exec time from quote];}
getmktdata:{[] getexchdata each key exchurl;}
/getexchdata:{[exch] (value exch) .j.k curlexch exchurl[exch]; }
getexchdata:{[exch] res:@[curlexch;exchurl[exch];{[x;e] -2"Failed to get exch",string[x];}[exch]]; if[1<count res;(value exch) .j.k res];}

curlinit:(`$"./libcurlkdb")2:(`kx_curl_init;1)
curlexch:(`$"./libcurlkdb")2:(`kx_curl_exch;1)
curlinit[`]

.ccy.fiat:`USD`EUR;
.ccy.cryp:`BTC`LTE`XRP;

.fees.trade:{[ex;bs;amt] k:(ex;bs);fees[k;`tradev]*amt}
.fees.draw:{[ex;bs;amt] k:(ex;bs);fees[k;`drawmin]|fees[k;`drawf]+fees[k;`drawv]*amt}
.fees.dep:{[ex;bs;amt] k:(ex;bs);fees[k;`depmin]|fees[k;`depf]+fees[k;`depv]*amt}
.fees.arb:{[endf;bank;ex1;ex2;amt1;amt2;btcpx] ((amt1%valatrisk)*.fees.draw[bank;`USD;amt1]) + .fees.dep[ex1;`USD;amt1] + .fees.trade[ex1;`USD;amt1] + (btcpx*(.fees.draw[ex1;`BTC;amt1%btcpx] + .fees.dep[ex2;`BTC;amt1%btcpx])) + .fees.trade[ex2;`USD;amt2] + endf*(.fees.draw[ex2;`USD;amt2] + .fees.dep[bank;`USD;amt2])}
.schema.fees:([]timestamp:`timestamp$();baseccy:`$();exch:`$();drawf:`float$();drawv:`float$();drawmin:`float$();depf:`float$();depv:`float$();depmin:`float$();tradev:`float$());
fees:`exch`baseccy xkey .schema.fees;
loadfees:{[fnm]
	tmp: ("SSFFFFFFF";enlist csv) 0: read0 hsym `$fnm;
	`fees upsert `timestamp xcols update timestamp:.z.P from tmp;
	}
loadfees["/Users/gabriel/Documents/cryptoC/kdb/ckdb/src/fees.csv"];
arbopts:([]time:`time$();sym:`$();buyexch:`$();sellexch:`$();amount:`float$();wbpx:`float$();wspx:`float$();val:`float$();gpnl:`float$();fees:`float$();nroi:`float$());
getarbstm:{[tm;val;exch1;exch2]
	exch1q:quote asof `exch`time!(exch1;tm);
	exch2q:quote asof `exch`time!(exch2;tm);
	if[exch1q[`apx]<exch2q[`bpx];
		getarbqt[val;exch1;exch2;exch1q;exch2q;tm];
	];
	}
getarbqt:{[val;exch1;exch2;exch1q;exch2q;tm]
	buypxl:exch1q[`aprcs] where exch1q[`aprcs]<exch2q[`bpx];
	if[count buypxl;
		buyamtl:(count buypxl)#exch1q[`aszs];
		vall:(+) scan buypxl * buyamtl;
		buycnt:count buys:buypxl where (vall<val);
		lastbuy:buypxl buycnt;
		lastsz:($[(vd:val-vall[(buycnt-1)|0])>0;vd;val])%lastbuy;
		valb:sum (buypxl:buys,lastbuy)*buysl:(buyamtl where (vall<val)),lastsz;
		bwpx:buysl wavg buypxl;
		sellcnt:count sellszl:exch2q[`bszs] where not (sells:(+) scan exch2q[`bszs])>sum buysl;
		lastsellsz:(sum buysl)-sum sellszl;
		sellval:sum (sellszl:sellszl,lastsellsz) * (sellpxl:(sellcnt+1)#exch2q[`bprcs]);
		gpnl:(sellval-valb);
	    if[gpnl<=0;:()];
		nroi:100*(gpnl-fees:.fees.arb[0b;`citigold;exch1;exch2;valb;sellval;bwpx])%valb;
		`arbopts upsert narb:(tm;`BTCUSD;exch1;exch2;sum buysl;bwpx;sellszl wavg sellpxl;valb;gpnl;fees;nroi);
	];
	}
getarbsexch:{[val;tml;exch1;exch2] raze getarbstm[;val;exch1;exch2] each tml}
getallarbs:{[val]
	exchtm:first exec exch from `x xdesc select count i by exch from quote;
	tml:exec distinct timestamp from quote where exch=exchtm;
	getarbsexch[val;tml] .' arbexchl::(exchcombo) where (not (=) .' exchcombo:(key exchurl) cross (key exchurl));
	}
getarbs:{[val;tm] getarbstm[tm;val] .' arbexchl::(exchcombo) where (not (=) .' exchcombo:(key exchurl) cross (key exchurl)); }