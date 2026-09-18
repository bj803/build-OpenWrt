'use strict';
'require view';
'require rpc';

var callStatus = rpc.declare({ object: 'luci.bbr', method: 'status', expect: {} });
var callSet    = rpc.declare({ object: 'luci.bbr', method: 'set', params: [ 'cc', 'qdisc' ], expect: {} });

return view.extend({
	load: function() {
		return callStatus();
	},

	render: function(st) {
		st = st || {};

		var ccCell    = E('td', { 'class': 'td left' }, st.cc || '-');
		var qdiscCell = E('td', { 'class': 'td left' }, st.qdisc || '-');
		var note      = E('span', { 'style': 'margin-left:12px' }, '');

		function row(k, v) {
			return E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '30%' }, k),
				E('td', { 'class': 'td left' }, v)
			]);
		}

		function colorize(v, want) {
			return E('strong', { 'style': 'color:' + (v === want ? 'green' : '#c00') }, v || '-');
		}

		var ccSel = E('select', { 'class': 'cbi-input-select' },
			[ 'bbr', 'cubic', 'reno' ].map(function(x) {
				return E('option', { 'value': x, 'selected': st.cc === x ? 'selected' : null }, x);
			}));
		var qSel = E('select', { 'class': 'cbi-input-select' },
			[ 'fq', 'fq_codel' ].map(function(x) {
				return E('option', { 'value': x, 'selected': st.qdisc === x ? 'selected' : null }, x);
			}));

		var btn = E('button', { 'class': 'cbi-button cbi-button-apply' }, '应用');
		btn.addEventListener('click', function() {
			btn.disabled = true;
			note.textContent = ' 应用中…';
			callSet(ccSel.value, qSel.value).then(function(ns) {
				ns = ns || {};
				ccCell.innerHTML = '';
				ccCell.appendChild(colorize(ns.cc, 'bbr'));
				qdiscCell.innerHTML = '';
				qdiscCell.appendChild(colorize(ns.qdisc, 'fq'));
				note.textContent = ' 当前: ' + (ns.cc || '?') + ' / ' + (ns.qdisc || '?') +
					'（' + (ns.persist || '未持久化') + '）';
			}).catch(function(e) {
				note.textContent = ' 失败: ' + e;
			}).then(function() {
				btn.disabled = false;
			});
		});

		return E('div', {}, [
			E('h2', {}, 'BBR 拥塞控制'),
			E('div', { 'class': 'cbi-map-descr' },
				'BBR 由内核模块 kmod-tcp-bbr 提供（本页只做开关与状态显示，不含 flow offload 等加速功能）。'),

			E('fieldset', { 'class': 'cbi-section' }, [
				E('legend', {}, '当前状态'),
				E('table', { 'class': 'table' }, [
					row('拥塞算法 (tcp_congestion_control)', ccCell),
					row('队列算法 (default_qdisc)', qdiscCell),
					row('内核对 bbr 是否可用', st.bbr_ok ? E('strong', { 'style': 'color:green' }, '可用') : E('strong', { 'style': 'color:#c00' }, '不可用')),
					row('内核模块 tcp_bbr.ko', (st.kmod_ok ? '已安装 / ' : '未安装 / ') + (st.kernel || '')),
					row('内核可用算法', st.avail || '-'),
					row('持久化位置', st.persist || '未持久化（重启后回到默认）')
				])
			]),

			E('fieldset', { 'class': 'cbi-section' }, [
				E('legend', {}, '修改'),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, '拥塞算法'),
					E('div', { 'class': 'cbi-value-field' }, ccSel)
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, '队列算法'),
					E('div', { 'class': 'cbi-value-field' }, qSel)
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, ' '),
					E('div', { 'class': 'cbi-value-field' }, [ btn, note ])
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title' }, ' '),
					E('div', { 'class': 'cbi-value-field', 'style': 'color:#666' },
						'推荐 bbr + fq；写入 /etc/sysctl.d/13-home-bbr-fq.conf，重启后保持。')
				])
			])
		]);
	}
});
