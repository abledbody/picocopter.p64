return function(props,pt)
	local size = props.size
	pt -= props.pivot*size
	
	local tex = props.tex
	local spr = get_spr(tex)
	
	sspr(tex,0,0,spr:width(),spr:height(),pt.x,pt.y,size.x,size.y)
end