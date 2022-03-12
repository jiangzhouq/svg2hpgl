<?xml version="1.0" encoding="utf-8"?>
<!-- XSL transformation to translate SVG documents into HPGL/1 plotting instructions. -->
<!-- 
   * This requires a XSL Level 3 capable processor such as saxon 9
   * There are some assumptions made, in particular about the default paper orientation
   * inkscape = upright, plotter = landscape
   * and the default pen colors as per the 7475A six pen carousel with the HP default
   * colors. Both can be changed in the code segments below.
   *
   * (c) by Timo Biesebach, 2019-2022
   * This code is placed in the public domain and can be freely distributed as long as
   * this notice is being retained.
  -->
<xsl:stylesheet version="2.0"     
    xmlns:svg="http://www.w3.org/2000/svg" 
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="math"
    xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
>
    <xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
    <xsl:strip-space elements="*"/>
	
	<!-- idmatrix is the identity matrix -->
	<xsl:variable name="idmatrix" select="'1.0,0,0,1.0,0,0'"/>
	
	<!-- 90 degrees rotation since the plotter works in landscape mode by default, assuming format in svg file is upright -->
	<xsl:variable name="rotate" select="number(0)"/>
	
	<!-- Setup global scale variables from viewBox="0 0 1190.55 841.89" -->
	<xsl:variable name="xmin">
		<xsl:value-of select="/svg:svg/tokenize(@viewBox, ' ')[2]"/>
	</xsl:variable>

	<xsl:variable name="ymin">
		<xsl:value-of select="/svg:svg/tokenize(@viewBox, ' ')[2]"/>
	</xsl:variable>

	<xsl:variable name="xmax">
		<xsl:value-of select="/svg:svg/tokenize(@viewBox, ' ')[3]"/>
	</xsl:variable>

	<xsl:variable name="ymax">
		<xsl:value-of select="/svg:svg/tokenize(@viewBox, ' ')[4]"/>
	</xsl:variable>

	<xsl:variable name="xdim">
		<xsl:value-of select="$xmax - $xmin"/>
	</xsl:variable>

	<xsl:variable name="ydim">
		<xsl:value-of select="$ymax - $ymin"/>
	</xsl:variable>

	<!-- Constant enumeration specifying pen color to physical number -->
	<xsl:variable name="pens">
		<entry key="BLACK" >1</entry>	    	    
	    <entry key="RED"   >3</entry>
	    <entry key="GREEN" >4</entry>
	    <entry key="BLUE"  >5</entry>
	    <entry key="VIOLET">5</entry>
	    <entry key="YELLOW">6</entry>
	    <entry key="BROWN" >1</entry>
  	</xsl:variable>
  	
  	<!-- In case a style element is found on the svg root level, build a map w.t. styles -->
	<xsl:variable name="styles">
		<!-- xsl:value-of select="/svg:svg/svg:style"/ -->
		<xsl:for-each select="/svg:svg/svg:style/tokenize(normalize-space(.),'\s+')">
			<xsl:variable name="entry" select="normalize-space(substring-before(substring-after(.,'{'),'}'))"/>
			<xsl:variable name="key"   select="normalize-space(substring-before(.,'{'))"/>
			<!-- xsl:message terminate="no">Style       |<xsl:value-of select="."/>|</xsl:message>
			<xsl:message terminate="no">Style Key   |<xsl:value-of select="$key"/>|</xsl:message>
			<xsl:message terminate="no">Style Entry |<xsl:value-of select="$entry"/>|</xsl:message -->
			<entry><xsl:attribute name="key"><xsl:value-of select="$key"/></xsl:attribute><xsl:value-of select="$entry"/></entry>
		</xsl:for-each>
	</xsl:variable>
	
  	<!-- Conversion between Inkscape pixel 1/90 inch and cm -->
	<xsl:variable name="px2cm" select="2.54 div 90.0"/>
	
	<!-- Unit of character width and height is specified in cm. Initial values is 0.285cm width and 0.375cm height. -->
  	<!-- xsl:variable name="text_wh" select="0.285 div 0.375"/ -->
	<xsl:variable name="text_wh" select="number(0.4)"/>
	  	
	<!-- Creates a transformation matrix from rotate, scale and translate commands, output will be the six-element a,b,c,d,e,f -->
	<!-- 
		translate(<tx> [<ty>]), which specifies a translation by tx and ty. If <ty> is not provided, it is assumed to be zero.
		scale(<sx> [<sy>]), which specifies a scale operation by sx and sy. If <sy> is not provided, it is assumed to be equal to <sx>. 
		rotate(<rotate-angle> [<cx> <cy>]), which specifies a rotation by <rotate-angle> degrees about a given point.
		If optional parameters <cx> and <cy> are not supplied, the rotate is about the origin of the current user coordinate system. The operation corresponds to the matrix [cos(a) sin(a) -sin(a) cos(a) 0 0].
		If optional parameters <cx> and <cy> are supplied, the rotate is about the point (cx, cy). The operation represents the equivalent of the following specification: translate(<cx>, <cy>) rotate(<rotate-angle>) translate(-<cx>, -<cy>). 
		skewX(<skew-angle>), which specifies a skew transformation along the x-axis.
		skewY(<skew-angle>), which specifies a skew transformation along the y-axis.
	 -->
	<xsl:template name="matrix-create">
		<xsl:param name="from"/>  <!-- from what to create the matrix -->
		<xsl:variable name="command"   select="substring-before($from,'(')"/>
		<xsl:variable name="params"    select="replace(substring-before(substring-after($from,'('),')'), '\s+',',')"/>
		<xsl:variable name="paramlist" select="tokenize($params, ',')"/>
		<!--
		<xsl:message terminate="no">Matrix From   |<xsl:value-of select="$from"/>|</xsl:message>
		<xsl:message terminate="no">Matrix Command|<xsl:value-of select="$command"/>|</xsl:message>
		<xsl:message terminate="no">Matrix Params |<xsl:value-of select="$params"/>|</xsl:message>
		-->
		<xsl:message terminate="no">Matrix Params |<xsl:value-of select="$paramlist"/>|</xsl:message>
		<xsl:choose>
		  <xsl:when test="$command='matrix'"> <!-- pass the paramlist as is -->
			<xsl:message terminate="no">Transform Matrix</xsl:message>
		  	<xsl:value-of select="$params"/>
		  </xsl:when>
		  <xsl:when test="$command='translate'">
		  	<xsl:message terminate="no">Translation Matrix</xsl:message>
		  	<xsl:variable name="tx" select="number($paramlist[1])"/>
		  	<xsl:variable name="ty" select="number(replace($paramlist[2], '', $paramlist[1]))"/>
		  	
		  	<xsl:variable name="a" select="1.0"/>
		  	<xsl:variable name="b" select="0.0"/>
		  	<xsl:variable name="c" select="0.0"/>
		  	<xsl:variable name="d" select="1.0"/>		  	
		  	<xsl:variable name="e" select="$tx"/>
		  	<xsl:variable name="f" select="$ty"/>		  	
		  	<xsl:value-of select="concat($a,',',$b,',',$c,',',$d,',',$e,',',$f)"/>
		  </xsl:when>
		  <xsl:when test="$command='scale'">		  	
		  	<xsl:message terminate="no">Scale Matrix</xsl:message>
		  	<xsl:variable name="sx" select="number($paramlist[1])"/>
		  	<xsl:variable name="sy" select="$sx"/>
		  	<!-- Todo: Rework the below. Replace with blank does not work -->
		  	<!--  xsl:variable name="sy" select="number(replace($paramlist[2], '', $paramlist[1]))"/ -->		  	
		  	<xsl:variable name="a" select="$sx"/>
		  	<xsl:variable name="b" select="0.0"/>		  	
		  	<xsl:variable name="c" select="0.0"/>
		  	<xsl:variable name="d" select="$sy"/>		  	
		  	<xsl:variable name="e" select="0.0"/>
		  	<xsl:variable name="f" select="0.0"/>		  	
		  	<xsl:value-of select="concat($a,',',$b,',',$c,',',$d,',',$e,',',$f)"/>
		  </xsl:when>
		  <xsl:when test="$command='rotate'">
		  	<xsl:message terminate="no">Rotate Matrix</xsl:message>
		  	<xsl:variable name="angleRad" select="number($paramlist[1]) * math:pi() div 180.0"/>
		  	<xsl:message terminate="no">Angle <xsl:value-of select="$angleRad"/></xsl:message>
		  	<xsl:variable name="a" select="math:cos($angleRad)"/>
		  	<xsl:variable name="b" select="math:sin($angleRad)"/>		  	
		  	<xsl:variable name="c" select="-math:sin($angleRad)"/>
		  	<xsl:variable name="d" select="math:cos($angleRad)"/>		  	
		  	<xsl:variable name="e" select="0.0"/>
		  	<xsl:variable name="f" select="0.0"/>	  	
		  	<xsl:value-of select="concat($a,',',$b,',',$c,',',$d,',',$e,',',$f)"/>
		  </xsl:when>
		  <xsl:when test="$command='skewX'">
		  	<xsl:message terminate="no">SkewX Matrix</xsl:message>
		  	<xsl:variable name="axRad" select="number(paramlist[1]) * math:pi() div 180.0"/>
		  	<xsl:variable name="a" select="1.0"/>
		  	<xsl:variable name="b" select="0.0"/>
		  	<xsl:variable name="c" select="math:tan($axRad)"/>
		  	<xsl:variable name="d" select="1.0"/>		  	
		  	<xsl:variable name="e" select="0.0"/>
		  	<xsl:variable name="f" select="0.0"/>		  	
		  	<xsl:value-of select="concat($a,',',$b,',',$c,',',$d,',',$e,',',$f)"/>		  	
		  </xsl:when>
		  <xsl:when test="$command='skewY'">
		  	<xsl:message terminate="no">SkewY Matrix</xsl:message>
		  	<xsl:variable name="ayRad" select="number(paramlist[1]) * math:pi() div 180.0"/>
		  	<xsl:variable name="a" select="1.0"/>
		  	<xsl:variable name="b" select="math:tan($ayRad)"/>		  	
		  	<xsl:variable name="c" select="0.0"/>
		  	<xsl:variable name="d" select="1.0"/>  	
		  	<xsl:variable name="e" select="0.0"/>
		  	<xsl:variable name="f" select="0.0"/>		  	
		  	<xsl:value-of select="concat($a,',',$b,',',$c,',',$d,',',$e,',',$f)"/>		  	
		  </xsl:when>
		  <xsl:otherwise> <!-- If no valid transform found then return the identity matrix -->
		  	<xsl:message terminate="no">Identity Matrix</xsl:message>
		  	<xsl:value-of select="$idmatrix"/>
		  </xsl:otherwise>
		</xsl:choose>
	</xsl:template>	
	
	<!-- Apply a 2d matrix transform specified by m to the 2d vector specified by v and output the result in form of 'x,y ' -->
	<xsl:template name="matrix-transform">
		<xsl:param name="m"/>  <!-- SVG 6 element matrix a,b,c,d,e,f will be expanded as [a c e / b d f / 0 0 1] matrix -->
		<xsl:param name="v"/>  <!-- SVG 2d vector x,y will be expanded into [x y 1] vector  -->
		<xsl:variable name="matrix" select="tokenize(normalize-space($m), ',')"/>
		<xsl:variable name="vector" select="tokenize(normalize-space($v), ',')"/>
		<xsl:variable name="x" select="number($matrix[1]) * number($vector[1]) + number($matrix[3]) * number($vector[2]) + number($matrix[5])"/>
		<xsl:variable name="y" select="number($matrix[2]) * number($vector[1]) + number($matrix[4]) * number($vector[2]) + number($matrix[6])"/>
		<!-- Change drawing orientation if so selected -->
		<xsl:choose>
		  <!-- We need to transform the coordinates for non-rotated orientation since SVG and Plotter have different Y axis orientations -->
		  <xsl:when test="not($rotate) or $rotate=0">
		  	<xsl:value-of select="concat( $x, ',' , $y, ' ' )"/> <!-- $ydim - figure out how to add back-->
		  </xsl:when>
		  <xsl:otherwise>
		  	<xsl:value-of select="concat( $y, ',' , $x, ' ' )"/>
		  </xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- Converts a 2digit hex number specified by parameter h into a decimal 0-255 -->
	<xsl:template name="hex2dec">
		<xsl:param name="h"/>  <!-- 2digit hex string i.e. "a0" -->
		<!-- recurse to process entire string -->
		<xsl:variable name="r">
			<xsl:choose>
				<xsl:when test="string-length($h)>1">
					<xsl:call-template name="hex2dec">
						<xsl:with-param name="h" select="substring($h, 1, string-length($h)-1)"/>
					</xsl:call-template>
				</xsl:when>
				<xsl:otherwise>0</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="d" select="substring($h, string-length($h), 1)"/>
		<xsl:variable name="s">
		<xsl:choose>
			<xsl:when test="lower-case($d)='a'">10</xsl:when>
			<xsl:when test="lower-case($d)='b'">11</xsl:when>
			<xsl:when test="lower-case($d)='c'">12</xsl:when>
			<xsl:when test="lower-case($d)='d'">13</xsl:when>
			<xsl:when test="lower-case($d)='e'">14</xsl:when>
			<xsl:when test="lower-case($d)='f'">15</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$d"/>
			</xsl:otherwise>
		</xsl:choose>
		</xsl:variable>
		<xsl:variable name="dec" select="$r * 16 + $s"/>
		<xsl:value-of select="$dec"/>
	</xsl:template>	
	
	<!-- Converts rgb color code into a pen number, this is a naiive implementation and uses the pens constant to convert to physical slot number -->
	<xsl:template name="rgb2pen">
		<xsl:param name="rgb"/>  <!-- rgb 3xhex color code #123456 -->
		<xsl:variable name="r" select="substring($rgb, 1, 2)"/>
		<xsl:variable name="g" select="substring($rgb, 3, 2)"/>
		<xsl:variable name="b" select="substring($rgb, 5, 2)"/>
		
		<xsl:variable name="dr">
			<xsl:call-template name="hex2dec">
				<xsl:with-param name="h" select="$r"/>
			</xsl:call-template>
		</xsl:variable>
		
		<xsl:variable name="dg">
			<xsl:call-template name="hex2dec">
				<xsl:with-param name="h" select="$g"/>
			</xsl:call-template>
		</xsl:variable>

		<xsl:variable name="db">
			<xsl:call-template name="hex2dec">
				<xsl:with-param name="h" select="$b"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:message terminate="no">Pen Color |<xsl:value-of select="$dr"/>|<xsl:value-of select="$dg"/>|<xsl:value-of select="$db"/>|</xsl:message>
		<!-- Naiive pen selection rule -->
		<xsl:variable name="colorname">
			<xsl:choose>
				<xsl:when test="number($dr)>number($dg) and number($dr)>number($db)">RED</xsl:when>
				<xsl:when test="number($dg)>number($dr) and number($dg)>number($db)">GREEN</xsl:when>
				<xsl:when test="number($db)>number($dr) and number($db)>number($dg)">BLUE</xsl:when>
				
				<xsl:when test="number($dr)=number($dg) and number($dr)>number($db)">YELLOW</xsl:when>
				<xsl:when test="number($dr)=number($db) and number($dr)>number($dg)">VIOLET</xsl:when>
				<xsl:when test="number($dg)=number($db) and number($dg)>number($dr)">BROWN</xsl:when>
				<xsl:otherwise>BLACK</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- Retrieve pen from mapping table -->
		<xsl:message terminate="no">Pen Color selection |<xsl:value-of select="$colorname"/>|</xsl:message>
		<xsl:value-of select="$pens/entry[@key=$colorname]"/>
		<xsl:message terminate="no">Pen selected |<xsl:value-of select="$pens/entry[@key=$colorname]"/>|</xsl:message>
	</xsl:template>	

	<!--  ************  HPGL Drawing  ************************************ -->
	<!--  templates to output HPGL/1 commands.                             -->
	<!--  ************  HPGL Drawing  ************************************ -->	
    
    <!-- Initialize Plot Defaults, we use characterset 33 (german) and the ASCII char 127 as label terminator. -->
    <xsl:template name="hpgl-init">
    	<xsl:param name="scaling"/>
    	<xsl:text>IN;DF;IP;DT&#127;;CS33;</xsl:text>
    	<!-- Correct SC box xmin xmax ymin ymax -->
    	<!-- note the ymin/ymax reversal due to different coordinate systems of SVG and the plotter -->
    	<xsl:text>SC</xsl:text>
    	<xsl:value-of select="concat($xmin,',',$xmax,',',$ymax,',',$ymin)"/> 
    	<xsl:text>;</xsl:text>
		<xsl:text>SP1;PA0,0;</xsl:text>
    </xsl:template>

    <xsl:template name="hpgl-pendown">
    	<xsl:text>PD;</xsl:text>
    </xsl:template>		   

	<xsl:template name="hpgl-pendown-point">
    	<xsl:param name="to"/>
    	<xsl:text>PD</xsl:text>
    	<xsl:value-of select="$to"/>
    	<xsl:text>;</xsl:text>
	</xsl:template>
	
    <xsl:template name="hpgl-penup">
    	<xsl:text>PU;</xsl:text>
    </xsl:template>		   

    <xsl:template name="hpgl-plotrel">
    	<xsl:param name="to"/>
    	<xsl:text>PR</xsl:text>
    	<xsl:value-of select="$to"/>
    	<xsl:text>;</xsl:text>
    </xsl:template>		   

    <xsl:template name="hpgl-plotabs">
    	<xsl:param name="to"/>
    	<xsl:text>PA</xsl:text>
    	<xsl:value-of select="normalize-space($to)"/>
    	<xsl:text>;</xsl:text>    
    </xsl:template>
    
    <xsl:template name="hpgl-selectpen">
    	<xsl:param name="number"/>
    	<xsl:text>SP</xsl:text>
    	<xsl:value-of select="$number"/>
    	<xsl:text>;</xsl:text>
    </xsl:template>
    
    <xsl:template name="hpgl-text-direction">
    	<xsl:param name="vector"/>
    	<xsl:text>DI</xsl:text>
    	<xsl:value-of select="$vector"/>
    	<xsl:text>;</xsl:text>
	</xsl:template>

	<!-- SR command sets text size relative in percent to the user coordinate system. 
	     1px in SVG is one unit, thus we calculate size as percent of ydim -->
	<xsl:template name="hpgl-text-size">
		<xsl:param name="size"/>
		<xsl:text>SR</xsl:text>
		<xsl:value-of select="$size * 100.0 div $xdim * $text_wh"/>
		<xsl:text>,</xsl:text>
		<xsl:value-of select="$size * 100.0 div $ydim"/>
		<xsl:text>;</xsl:text>
	</xsl:template>

	<xsl:template name="hpgl-text-label">
		<xsl:param name="text"/>
    	<xsl:text>LB</xsl:text>
    	<xsl:value-of select="$text"/>
    	<xsl:text>&#127;</xsl:text>
	</xsl:template>
	
	<xsl:template name="hpgl-arc-abs">
		<xsl:param name="endpoint"/>
		<xsl:param name="angle"/>
		<xsl:text>AA</xsl:text>
    	<xsl:value-of select="$endpoint"/>
    	<xsl:text>,</xsl:text>
    	<xsl:value-of select="$angle"/>
    	<xsl:text>;</xsl:text>
	</xsl:template>
	
	<xsl:template name="hpgl-edge-abs">
		<xsl:param name="endpoint"/>
		<xsl:param name="opacity"/>
    	<!-- If opacity given, determine fill pattern -->
		<xsl:if test="number($opacity)>0">
			<xsl:text>FT3,</xsl:text>
			<xsl:value-of select="(1.0-number($opacity))*10.0"/>
			<xsl:text>,45;</xsl:text>
			<xsl:text>RA</xsl:text>  <!-- start filled rect -->
			<xsl:value-of select="$endpoint"/>
			<xsl:text>;</xsl:text>			
		</xsl:if>
		<xsl:text>EA</xsl:text>  <!-- start outline rect -->
		<xsl:value-of select="$endpoint"/>
		<xsl:text>;</xsl:text>					
	</xsl:template>
	
	<!-- HPGL/2 bezier curve emulation -->
	<xsl:template name="hpgl-emulate-br-points">		   
        <xsl:param name="b0"/>
    	<xsl:param name="b1"/>
    	<xsl:param name="b2"/>
    	<xsl:param name="b3"/>
    	<xsl:param name="ti"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="absmode"/>
		
		<!-- Split the vectors up into x,y components for calculations -->		
		<xsl:variable name="lx" select="number(head(tokenize(normalize-space($lastpoint), ',')))"/>
		<xsl:variable name="ly" select="number(tail(tokenize(normalize-space($lastpoint), ',')))"/>
		
		<xsl:variable name="b0x" select="number(head(tokenize(normalize-space($b0), ',')))"/>
		<xsl:variable name="b0y" select="number(tail(tokenize(normalize-space($b0), ',')))"/>
		<xsl:variable name="b1x" select="number(head(tokenize(normalize-space($b1), ',')))"/>
		<xsl:variable name="b1y" select="number(tail(tokenize(normalize-space($b1), ',')))"/>
		<xsl:variable name="b2x" select="number(head(tokenize(normalize-space($b2), ',')))"/>
		<xsl:variable name="b2y" select="number(tail(tokenize(normalize-space($b2), ',')))"/>
		<xsl:variable name="b3x" select="number(head(tokenize(normalize-space($b3), ',')))"/>
		<xsl:variable name="b3y" select="number(tail(tokenize(normalize-space($b3), ',')))"/>

		<xsl:variable name="t" select="$ti div 10.0"/>
		
	    <xsl:variable name="b10x" select="(1.0-$t)*$b0x + ($t*$b1x)"/>
	    <xsl:variable name="b11x" select="(1.0-$t)*$b1x + ($t*$b2x)"/>
	    <xsl:variable name="b12x" select="(1.0-$t)*$b2x + ($t*$b3x)"/>
	    <xsl:variable name="b30x" select="(1.0-$t)*((1.0-$t) * $b10x + $t*$b11x) + $t*((1.0-$t)*$b11x + $t*$b12x)"/>
	 		    
	    <xsl:variable name="b10y" select="(1.0-$t)*$b0y + ($t*$b1y)"/>
	    <xsl:variable name="b11y" select="(1.0-$t)*$b1y + ($t*$b2y)"/>
	    <xsl:variable name="b12y" select="(1.0-$t)*$b2y + ($t*$b3y)"/>
	    <xsl:variable name="b30y" select="(1.0-$t)*((1.0-$t) * $b10y + $t*$b11y) + $t*((1.0-$t)*$b11y + $t*$b12y)"/>
	    
	    <xsl:variable name="b30">
	    <xsl:choose>
	    <xsl:when test="not($absmode)">
		    <xsl:value-of select="concat($b30x - $lx,',',$b30y - $ly)"/>
		</xsl:when>
	    <xsl:otherwise>
		    <xsl:value-of select="concat($b30x,',',$b30y)"/>
		</xsl:otherwise>
	    </xsl:choose>
	    </xsl:variable>

		<xsl:if test="not($absmode)">
		<xsl:text>PR</xsl:text><xsl:value-of select="$b30"/><xsl:text>;</xsl:text>
		</xsl:if>
		<xsl:if test="$absmode">
		<xsl:text>PA</xsl:text><xsl:value-of select="$b30"/><xsl:text>;</xsl:text>
		</xsl:if>
	    
	    <xsl:message terminate="no">hpgl-emulate-br-points::t=<xsl:value-of select="$t"/></xsl:message>
	    <xsl:message terminate="no">hpgl-emulate-br-points::lastpoint=<xsl:value-of select="$lx"/>, <xsl:value-of select="$ly"/></xsl:message>
	    <xsl:message terminate="no">hpgl-emulate-br-points::b30xy=<xsl:value-of select="$b30x"/>, <xsl:value-of select="$b30y"/></xsl:message>	    	    
		<xsl:message terminate="no">hpgl-emulate-br-points::b30=<xsl:value-of select="$b30"/></xsl:message>
		
		<xsl:if test="10 > $ti">
			<xsl:call-template name="hpgl-emulate-br-points">
		        <xsl:with-param name="b0" select="$b0"/>
		    	<xsl:with-param name="b1" select="$b1"/>
		    	<xsl:with-param name="b2" select="$b2"/>
		    	<xsl:with-param name="b3" select="$b3"/>
		    	<xsl:with-param name="ti" select="$ti + 1"/>
		    	<xsl:with-param name="lastpoint" select="concat($b30x,',',$b30y)"/>
		    	<xsl:with-param name="absmode" select="$absmode"/>
			</xsl:call-template> 
		</xsl:if>   	
	</xsl:template>
	
	<!-- Emulates the BR command by approximating a bezier curve with linesegments -->
    <xsl:template name="hpgl-emulate-br">		   
        <xsl:param name="b0"/>
    	<xsl:param name="b1"/>
    	<xsl:param name="b2"/>
    	<xsl:param name="b3"/>
    	<xsl:param name="absmode"/>
    	
		<xsl:call-template name="hpgl-emulate-br-points">
	        <xsl:with-param name="b0" select="$b0"/>
	    	<xsl:with-param name="b1" select="$b1"/>
	    	<xsl:with-param name="b2" select="$b2"/>
	    	<xsl:with-param name="b3" select="$b3"/>
	    	<xsl:with-param name="ti" select="0"/>
	    	<xsl:with-param name="lastpoint" select="'0.0,0.0'"/>
	    	<xsl:with-param name="absmode" select="$absmode"/> 
		</xsl:call-template>
	</xsl:template>
	
	<!--  ************  SVG Processing  ************************************ -->
	<!--  Process the svg root element and output HPGL initialization values -->
	<!--  ************  SVG Processing  ************************************ -->	
    <xsl:template match="svg:svg">
    	<xsl:message terminate="no">XDim |<xsl:value-of select="$xdim"/>|</xsl:message>
    	<xsl:message terminate="no">YDim |<xsl:value-of select="$ydim"/>|</xsl:message>

    	<xsl:call-template name="hpgl-init">
			<xsl:with-param name="scaling" select="tokenize(@viewBox, ' ')"/>
		</xsl:call-template>
    	<xsl:apply-templates select="svg:title"/>
    	<xsl:apply-templates select="svg:g"/>
    	<xsl:apply-templates/>
    	
    	<!-- Finally, store away the pen and view the page -->
    	<xsl:text>SP0;IN;</xsl:text>
    </xsl:template>
	
	<xsl:template match="svg:style">
		<xsl:message terminate="no">Style element ignored</xsl:message>
	</xsl:template>

	<xsl:template match="svg:title">
		<xsl:message terminate="no">Title element ignored</xsl:message>
	</xsl:template>
	
    <!-- Process group elements -->
    <xsl:template match="svg:g">
    	<xsl:message terminate="no">Group <xsl:value-of select="@id"/></xsl:message>
    	<xsl:variable name="style" select="@style"/>
    	<!-- Suppress hidden groups (typically layers from Inkscape -->
		<xsl:if test="not($style) or $style != 'display:none'">
			<xsl:apply-templates/>
		</xsl:if>
    </xsl:template>
	
	<!-- Process svg s-curve paths (lowercase: relative, uppercase absolute)
	     Needs the 2nd to last point of the previous c-curve (cpoint2)
	-->	
    <xsl:template name="svg:path-command-s">		   
        <xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
    	<xsl:param name="cursor"/>
		<xsl:param name="cpoint2"/>
		<xsl:param name="startpoint"/>
    	<xsl:message terminate="no">svg:path-command-c cmd <xsl:value-of select="$cmd"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c lastp <xsl:value-of select="$lastpoint"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c list <xsl:value-of select="$list"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c matrix <xsl:value-of select="$matrix"/></xsl:message>
    	    	    	
		<!-- Process 3 points -->
    	<xsl:variable name="p1"     select="head($list)"/>
    	<xsl:variable name="p1tail" select="tail($list)"/>
    	
    	<xsl:variable name="p2"     select="head($p1tail)"/>
    	<xsl:variable name="p2tail" select="tail($p1tail)"/>
    	
    	<xsl:message terminate="no">svg:path-command-c p1 <xsl:value-of select="$p1"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c p2 <xsl:value-of select="$p2"/></xsl:message>
	    	
    	<xsl:variable name="p1Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$p1"/>
			</xsl:call-template>
		</xsl:variable>

    	<xsl:variable name="p2Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$p2"/>
			</xsl:call-template>
		</xsl:variable>

    	<xsl:variable name="lastpointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$lastpoint"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-pendown"/>		
		
	
    	<!-- Bezier curve start point is 0,0 - the current pen position in both cases,
    	     However, control points may be relative or absolute.
    	     For the HPGL implementation we need relative data in both cases.
    	     
    	     s-curves are special in that they omit the first control point because
    	     it would be a reflection of the 2nd control point of the previous curve
    	     or if not given, the lastpoint of the last curve.
    	-->    	

		<!-- calculate the cpoint2 reflection -->
		<xsl:variable name="cp2x" select="number(head(tokenize(normalize-space($cpoint2), ',')))"/>
		<xsl:variable name="cp2y" select="number(tail(tokenize(normalize-space($cpoint2), ',')))"/>
		<xsl:variable name="lpx" select="number(head(tokenize(normalize-space($lastpoint), ',')))"/>
		<xsl:variable name="lpy" select="number(tail(tokenize(normalize-space($lastpoint), ',')))"/>
				
		<xsl:if test="$cmd = 's'">
			<xsl:variable name="cpoint_new">
					<xsl:value-of select="concat(number(1.0 * ($lpx - $cp2x)),',',number(1.0 * ($lpy - $cp2y)))"/>
			</xsl:variable>
			<xsl:variable name="cpoint_newTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$cpoint_new"/>
				</xsl:call-template>
			</xsl:variable>
				
		    <xsl:call-template name="hpgl-emulate-br">
		        <xsl:with-param name="b0" select="'0.0,0.0'"/>
		    	<xsl:with-param name="b1" select="normalize-space($cpoint_newTx)"/>
		    	<xsl:with-param name="b2" select="normalize-space($p1Tx)"/>
		    	<xsl:with-param name="b3" select="normalize-space($p2Tx)"/>
		    </xsl:call-template>
	    </xsl:if>
		<xsl:if test="$cmd = 'S'">
			<xsl:variable name="cpoint_new">
					<xsl:value-of select="concat(number(2.0 * ($lpx - $cp2x)),',',number(2.0 * ($lpy - $cp2y)))"/>
			</xsl:variable>
			<xsl:variable name="cpoint_newTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$cpoint_new"/>
				</xsl:call-template>
			</xsl:variable>
		
		    <xsl:call-template name="hpgl-emulate-br">
		        <xsl:with-param name="b0" select="normalize-space($cursor)"/>
		    	<xsl:with-param name="b1" select="normalize-space($cpoint_newTx)"/>
		    	<xsl:with-param name="b2" select="normalize-space($p1Tx)"/>
		    	<xsl:with-param name="b3" select="normalize-space($p2Tx)"/>
		    	<xsl:with-param name="absmode" select="1"/>
		    	<!-- this will lead to a conversion abs to rel in the code -->
		    </xsl:call-template>
	    </xsl:if>
		<xsl:call-template name="hpgl-penup"/>
		
		<!-- Update the cursor -->
		<xsl:variable name="cx" select="number(head(tokenize(normalize-space($cursor), ',')))"/>
		<xsl:variable name="cy" select="number(tail(tokenize(normalize-space($cursor), ',')))"/>
		<xsl:variable name="p2x" select="number(head(tokenize(normalize-space($p2), ',')))"/>
		<xsl:variable name="p2y" select="number(tail(tokenize(normalize-space($p2), ',')))"/>
		<xsl:variable name="cursor_new">
			<xsl:choose>
				<xsl:when test="$cmd='S'">
					<xsl:value-of select="$p2"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="concat(number($p2x+$cx),',',number($p2y+$cy))"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		
		<!-- call the path command again with the remaining list -->
		<xsl:variable name="point" select="head($p2tail)"/>
		<xsl:if test="not(contains($point, ','))">
			<xsl:message terminate="no">svg:path-command-S::call command <xsl:value-of select="$point"/></xsl:message>
			<xsl:message terminate="no">svg:path-command-s::cursor <xsl:value-of select="$cursor_new"/></xsl:message>
			<xsl:call-template name="svg:path-command">
				<xsl:with-param name="cmd" select="$point"/>
				<xsl:with-param name="list" select="tail($p2tail)"/>
				<xsl:with-param name="matrix" select="$matrix"/>
				<xsl:with-param name="lastpoint" select="$p2"/>
				<xsl:with-param name="cursor" select="$cursor_new"/>
				<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>				
		</xsl:if>
		<xsl:if test="contains($point, ',')">			
			<!-- Process remmaining points -->
			<xsl:call-template name="svg:path-command-c">
				<xsl:with-param name="cmd" select="$cmd"/>
				<xsl:with-param name="list" select="$p2tail"/>
				<xsl:with-param name="matrix" select="$matrix"/>			
		    	<xsl:with-param name="lastpoint" select="$p2"/>
		    	<xsl:with-param name="cursor" select="$cursor_new"/>
		    	<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>	

	<!-- Process svg c-curve paths (lowercase: relative, uppercase absolute)-->	
    <xsl:template name="svg:path-command-c">		   
        <xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
    	<xsl:param name="cursor"/>
		<xsl:param name="startpoint"/>
    	<xsl:message terminate="no">svg:path-command-c cmd <xsl:value-of select="$cmd"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c lastp <xsl:value-of select="$lastpoint"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c list <xsl:value-of select="$list"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c matrix <xsl:value-of select="$matrix"/></xsl:message>
    	    	    	
		<!-- Process 3 points -->
    	<xsl:variable name="p1"     select="head($list)"/>
    	<xsl:variable name="p1tail" select="tail($list)"/>
    	
    	<xsl:variable name="p2"     select="head($p1tail)"/>
    	<xsl:variable name="p2tail" select="tail($p1tail)"/>
    	
    	<xsl:variable name="p3"     select="head($p2tail)"/>
    	<xsl:variable name="p3tail" select="tail($p2tail)"/>
    	
    	
    	<xsl:message terminate="no">svg:path-command-c p1 <xsl:value-of select="$p1"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c p2 <xsl:value-of select="$p2"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c p3 <xsl:value-of select="$p3"/></xsl:message>
    	    	
    	<xsl:variable name="p1Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$p1"/>
			</xsl:call-template>
		</xsl:variable>

    	<xsl:variable name="p2Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$p2"/>
			</xsl:call-template>
		</xsl:variable>

    	<xsl:variable name="p3Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$p3"/>
			</xsl:call-template>
		</xsl:variable>

    	<xsl:variable name="lastpointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$lastpoint"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-pendown"/>		
		
		<xsl:message terminate="no">svg:path-command-c lptx <xsl:value-of select="$lastpointTx"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c p1tx <xsl:value-of select="$p1Tx"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c p2tx <xsl:value-of select="$p2Tx"/></xsl:message>
    	<xsl:message terminate="no">svg:path-command-c p3tx <xsl:value-of select="$p3Tx"/></xsl:message>
    	    
    	<!-- Bezier curve start point is 0,0 - the current pen position in both cases,
    	     However, control points may be relative or absolute.
    	     For the HPGL implementation we need relative data in both cases.
    	-->    	
		<xsl:if test="$cmd = 'c'">
		    <xsl:call-template name="hpgl-emulate-br">
		        <xsl:with-param name="b0" select="'0.0,0.0'"/>
		    	<xsl:with-param name="b1" select="normalize-space($p1Tx)"/>
		    	<xsl:with-param name="b2" select="normalize-space($p2Tx)"/>
		    	<xsl:with-param name="b3" select="normalize-space($p3Tx)"/>
		    </xsl:call-template>
	    </xsl:if>
		<xsl:if test="$cmd = 'C'">
		    <xsl:call-template name="hpgl-emulate-br">
		        <xsl:with-param name="b0" select="normalize-space($cursor)"/>
		    	<xsl:with-param name="b1" select="normalize-space($p1Tx)"/>
		    	<xsl:with-param name="b2" select="normalize-space($p2Tx)"/>
		    	<xsl:with-param name="b3" select="normalize-space($p3Tx)"/>
		    	<xsl:with-param name="absmode" select="1"/>
		    	<!-- this will lead to a conversion abs to rel in the code -->
		    </xsl:call-template>
	    </xsl:if>
		<xsl:call-template name="hpgl-penup"/>
		
		<xsl:variable name="cx" select="number(head(tokenize(normalize-space($cursor), ',')))"/>
		<xsl:variable name="cy" select="number(tail(tokenize(normalize-space($cursor), ',')))"/>
		
		<xsl:variable name="p3x" select="number(head(tokenize(normalize-space($p3), ',')))"/>
		<xsl:variable name="p3y" select="number(tail(tokenize(normalize-space($p3), ',')))"/>
		
		<!-- Update cursor tracking variable -->
		<xsl:variable name="cursor_new">
			<xsl:choose>
				<xsl:when test="$cmd='C'">
					<xsl:value-of select="$p3"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="concat(number($p3x+$cx),',',number($p3y+$cy))"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="point" select="head($p3tail)"/>
		<!-- a new command -->
		<xsl:if test="not(contains($point, ','))">
			<xsl:message terminate="no">svg:path-command-c::call command <xsl:value-of select="$point"/></xsl:message>
			<xsl:message terminate="no">svg:path-command-c::cursor <xsl:value-of select="$cursor_new"/></xsl:message>			
			<xsl:call-template name="svg:path-command">
				<xsl:with-param name="cmd" select="$point"/>
				<xsl:with-param name="list" select="tail($p3tail)"/>
				<xsl:with-param name="matrix" select="$matrix"/>
				<xsl:with-param name="lastpoint" select="$p3"/>
				<xsl:with-param name="cursor" select="$cursor_new"/>
				<xsl:with-param name="cpoint2" select="$p2"/>
				<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>				
		</xsl:if>
		<!-- Another set of points to continue the c-command -->
		<xsl:if test="contains($point, ',')">						
			<xsl:call-template name="svg:path-command-c">
				<xsl:with-param name="cmd" select="$cmd"/>
				<xsl:with-param name="list" select="$p3tail"/>
				<xsl:with-param name="matrix" select="$matrix"/>			
		    	<xsl:with-param name="lastpoint" select="$p3"/>
		    	<xsl:with-param name="cursor" select="$cursor_new"/>
		    	<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

	<!-- Process svg m-oveto paths (lowercase: relative, uppercase absolute)-->	
    <xsl:template name="svg:path-command-m">
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
    	<xsl:param name="cursor"/>
    	<xsl:param name="startpoint"/>
    	
		<!-- Process first point -->
    	<xsl:variable name="firstpoint" select="head($list)"/>
    	<xsl:variable name="points" select="tail($list)"/>
    	
    	<!-- We assume that the very first M command will start the path -->
    	<xsl:variable name="stemp" >
			<xsl:if test="not($startpoint)">
				<xsl:value-of select="$firstpoint"/>
			</xsl:if>
			<xsl:if test="$startpoint">
				<xsl:value-of select="$startpoint"/>
			</xsl:if>
    	</xsl:variable>
	
		<!-- Transform the firstpoint for rendering -->    	
    	<xsl:variable name="firstpointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$firstpoint"/>
			</xsl:call-template>
		</xsl:variable>
		
		<!-- Generate HPGL commands for initial point -->
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="normalize-space($firstpointTx)"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-pendown"/>
		<!-- Process remmaining points -->
		<xsl:call-template name="svg:path-command-m-points">
			<xsl:with-param name="cmd" select="$cmd"/>
			<xsl:with-param name="list" select="$points"/>
			<xsl:with-param name="matrix" select="$matrix"/>	
	    	<xsl:with-param name="lastpoint" select="$firstpoint"/>
	    	<xsl:with-param name="cursor" select="$cursor"/>
	    	<xsl:with-param name="startpoint" select="$stemp"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-penup"/>
	</xsl:template>
	
	<xsl:template name="svg:path-command-m-points">		
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
    	<xsl:param name="cursor"/>
    	<xsl:param name="startpoint"/>
		<!-- Update cursor -->
		<xsl:variable name="cursor_new">
			<xsl:choose>
				<xsl:when test="$cmd='M'">
					<xsl:value-of select="$lastpoint"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="cx" select="number(head(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:variable name="cy" select="number(tail(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:variable name="p3x" select="number(head(tokenize(normalize-space($lastpoint), ',')))"/>
					<xsl:variable name="p3y" select="number(tail(tokenize(normalize-space($lastpoint), ',')))"/>
					<xsl:value-of select="concat(number($p3x+$cx),',',number($p3y+$cy))"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- Inspect the point we got. It could be a command really (z:closepath, M/m moveto, L/l lineto.) -->
		<!-- If no comma in current point, then it's likely a command -->
		<xsl:variable name="point" select="head($list)"/>
		<xsl:if test="not(contains($point, ','))">
			<xsl:message terminate="no">svg:path-command-m-points::call command <xsl:value-of select="$point"/></xsl:message>
			<xsl:message terminate="no">svg:path-command-m-points::cursor <xsl:value-of select="$cursor_new"/></xsl:message>
			<xsl:call-template name="svg:path-command">
				<xsl:with-param name="cmd" select="$point"/>
				<xsl:with-param name="list" select="tail($list)"/>
				<xsl:with-param name="matrix" select="$matrix"/>
				<xsl:with-param name="lastpoint" select="$lastpoint"/>
				<xsl:with-param name="cursor" select="$cursor_new"/>
				<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>
		</xsl:if>
		<!-- It's a point, then generate movement command and process remaining points -->
		<xsl:if test="contains($point, ',')">
			<xsl:variable name="pointTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$point"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:if test="not(contains($pointTx, 'NaN'))">
				<xsl:if test="$cmd = 'm'">
					<xsl:call-template name="hpgl-plotrel">
						<xsl:with-param name="to" select="normalize-space($pointTx)"/>
					</xsl:call-template>
				</xsl:if>				
				<xsl:if test="$cmd = 'M'">
					<xsl:call-template name="hpgl-plotabs">
						<xsl:with-param name="to" select="normalize-space($pointTx)"/>
					</xsl:call-template>							
				</xsl:if>
			</xsl:if>
			<!-- Process remaining points -->			
			<xsl:call-template name="svg:path-command-m-points">
				<xsl:with-param name="cmd" select="$cmd"/>
				<xsl:with-param name="list" select="tail($list)"/>
				<xsl:with-param name="matrix" select="$matrix"/>			
		    	<xsl:with-param name="lastpoint" select="$point"/>
		    	<xsl:with-param name="cursor" select="$cursor_new"/>
		    	<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	
	<!-- Process svg l-ine paths (lowercase: relative, uppercase absolute)-->	
    <xsl:template name="svg:path-command-l">
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
	    <xsl:param name="cursor"/>
	    <xsl:param name="startpoint"/>
    	
		<!-- Process first point -->
    	<xsl:variable name="topoint" select="head($list)"/>
    	<xsl:variable name="points" select="tail($list)"/>
    	
		<!-- Transform the topoint for rendering -->    	
    	<xsl:variable name="topointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$topoint"/>
			</xsl:call-template>
		</xsl:variable>
		
		<!-- Generate HPGL commands for plotting to abs or rel point -->		
		<xsl:call-template name="hpgl-pendown"/>
		<xsl:if test="$cmd = 'l'">
			<xsl:call-template name="hpgl-plotrel">
				<xsl:with-param name="to" select="normalize-space($topointTx)"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="$cmd = 'L'">
			<xsl:call-template name="hpgl-plotabs">
				<xsl:with-param name="to" select="normalize-space($topointTx)"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:call-template name="hpgl-penup"/>
		<!-- Update cursor -->
		<xsl:variable name="cursor_new">
			<xsl:choose>
				<xsl:when test="$cmd='L'">
					<xsl:value-of select="$topoint"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="cx" select="number(head(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:variable name="cy" select="number(tail(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:variable name="px" select="number(head(tokenize(normalize-space($topoint), ',')))"/>
					<xsl:variable name="py" select="number(tail(tokenize(normalize-space($topoint), ',')))"/>
					<xsl:value-of select="concat(number($cx + number($px)),',',number($cy + number($py)))"/>					
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="next" select="head($points)"/>
		<xsl:choose>
			<xsl:when test="string(number($next)) = 'NaN'">
				<xsl:message terminate="no">svg:path-command-h::call command <xsl:value-of select="$next"/></xsl:message>
				<xsl:call-template name="svg:path-command">
					<xsl:with-param name="cmd" select="$next"/>
					<xsl:with-param name="list" select="tail($points)"/>
					<xsl:with-param name="matrix" select="$matrix"/>
					<xsl:with-param name="lastpoint" select="$lastpoint"/>
					<xsl:with-param name="cursor" select="$cursor_new"/>
					<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>				
			</xsl:when>
			<xsl:otherwise>
				<!-- Process remmaining points -->
				<xsl:call-template name="svg:path-command-h">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$points"/>
					<xsl:with-param name="matrix" select="$matrix"/>
			    	<xsl:with-param name="lastpoint" select="$cursor_new"/>
			    	<xsl:with-param name="cursor" select="$cursor_new"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:otherwise>	
		</xsl:choose>	
	</xsl:template>
	
	<!-- Process svg v-ertical paths (lowercase: relative, uppercase absolute)-->	
    <xsl:template name="svg:path-command-v">
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
 	    <xsl:param name="cursor"/>
 	    <xsl:param name="startpoint"/>
		<!-- Process first point -->
		<xsl:variable name="xlast"  select="head(tokenize(normalize-space($cursor), ','))"/>
    	<xsl:variable name="ycoord" select="head($list)"/>
    	<xsl:variable name="points" select="tail($list)"/>
		<!-- Generate HPGL commands for initial point -->
		<xsl:call-template name="hpgl-pendown"/>
		<xsl:if test="$cmd = 'v'">
			<xsl:variable name="point" select="concat('0.0,', $ycoord)"/>
			<xsl:variable name="pointTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$point"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-plotrel">
				<xsl:with-param name="to" select="normalize-space($pointTx)"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="$cmd = 'V'">
			<xsl:variable name="point" select="concat($xlast, ',', $ycoord)"/>
			<xsl:variable name="pointTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$point"/>
				</xsl:call-template>
			</xsl:variable>
		
			<xsl:call-template name="hpgl-plotabs">
				<xsl:with-param name="to" select="normalize-space($pointTx)"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:call-template name="hpgl-penup"/>
		<!-- Update cursor -->
		<xsl:variable name="cursor_new">
			<xsl:choose>
				<xsl:when test="$cmd='V'">
					<xsl:value-of select="concat($xlast, ',', $ycoord)"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="cx" select="number(head(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:variable name="cy" select="number(tail(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:value-of select="concat(number($cx),',',number($cy + number($ycoord)))"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- -->
		<xsl:variable name="next" select="head($points)"/>
		<xsl:choose>
			<!-- check if next element is numeric or a command -->
			<xsl:when test="string(number($next)) = 'NaN'">
				<xsl:message terminate="no">svg:path-command-v::call command <xsl:value-of select="$next"/></xsl:message>
				<xsl:message terminate="no">svg:path-command-v::cursor <xsl:value-of select="$cursor_new"/></xsl:message>
				<xsl:call-template name="svg:path-command">
					<xsl:with-param name="cmd" select="$next"/>
					<xsl:with-param name="list" select="tail($points)"/>
					<xsl:with-param name="matrix" select="$matrix"/>
					<xsl:with-param name="lastpoint" select="$lastpoint"/>
					<xsl:with-param name="cursor" select="$cursor_new"/>
					<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>				
			</xsl:when>
			<xsl:otherwise>
				<!-- Process remmaining points -->
				<xsl:call-template name="svg:path-command-v">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$points"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="concat($xlast, ',', $ycoord)"/>
			    	<xsl:with-param name="cursor" select="$cursor_new"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:otherwise>	
		</xsl:choose>	
	</xsl:template>

	<!-- Process svg h-orizontal paths (lowercase: relative, uppercase absolute)-->	
    <xsl:template name="svg:path-command-h">
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
	    <xsl:param name="cursor"/>
	    <xsl:param name="startpoint"/>
		<!-- Process first point -->
		<xsl:variable name="ylast"  select="head(tail(tokenize(normalize-space($cursor), ',')))"/>
    	<xsl:variable name="xcoord" select="head($list)"/>
    	<xsl:variable name="points" select="tail($list)"/>    	
		<!-- Generate HPGL commands for initial point -->		
		<xsl:call-template name="hpgl-pendown"/>
		<xsl:if test="$cmd = 'h'">
			<xsl:variable name="point" select="concat($xcoord, ',0.0')"/>
			<xsl:variable name="pointTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$point"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-plotrel">
				<xsl:with-param name="to" select="normalize-space($pointTx)"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="$cmd = 'H'">
			<xsl:variable name="point" select="concat($xcoord, ',', $ylast)"/>
			<xsl:variable name="pointTx">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$point"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-plotabs">
				<xsl:with-param name="to" select="normalize-space($pointTx)"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:call-template name="hpgl-penup"/>
		<!-- Update cursor -->
		<xsl:variable name="cursor_new">
			<xsl:choose>
				<xsl:when test="$cmd='H'">
					<xsl:value-of select="concat($xcoord, ',', $ylast)"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="cx" select="number(head(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:variable name="cy" select="number(tail(tokenize(normalize-space($cursor), ',')))"/>
					<xsl:value-of select="concat(number($cx + number($xcoord)),',',number($cy))"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="next" select="head($points)"/>
		<xsl:choose>
			<xsl:when test="string(number($next)) = 'NaN'">
				<xsl:message terminate="no">svg:path-command-h::call command <xsl:value-of select="$next"/></xsl:message>
				<xsl:call-template name="svg:path-command">
					<xsl:with-param name="cmd" select="$next"/>
					<xsl:with-param name="list" select="tail($points)"/>
					<xsl:with-param name="matrix" select="$matrix"/>
					<xsl:with-param name="lastpoint" select="$lastpoint"/>
					<xsl:with-param name="cursor" select="$cursor_new"/>
					<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>				
			</xsl:when>
			<xsl:otherwise>
				<!-- Process remmaining points -->
				<xsl:call-template name="svg:path-command-h">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$points"/>
					<xsl:with-param name="matrix" select="$matrix"/>
			    	<xsl:with-param name="lastpoint" select="concat($xcoord, ',', $ylast)"/>
			    	<xsl:with-param name="cursor" select="$cursor_new"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:otherwise>	
		</xsl:choose>	
	</xsl:template>
	
	<!-- Process svg z-close paths -->	
    <xsl:template name="svg:path-command-z">
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
    	<xsl:param name="cursor"/>
    	<xsl:param name="startpoint"/>
    	
		<!-- Plot a straight line back to the path starting point -->
    	<xsl:variable name="startpointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$startpoint"/>
			</xsl:call-template>
		</xsl:variable>
		
		<!-- Generate HPGL commands for closing path -->
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="normalize-space($startpointTx)"/>
		</xsl:call-template>

		<!-- if list contains any more elements, process them -->
		<xsl:if test="head($list)!=tail($list)">
			<xsl:variable name="next" select="head($list)"/>
			<xsl:message terminate="no">svg:path-command-z::call command <xsl:value-of select="$next"/></xsl:message>
			<xsl:call-template name="svg:path-command">
				<xsl:with-param name="cmd" select="$next"/>
				<xsl:with-param name="list" select="tail($list)"/>
				<xsl:with-param name="matrix" select="$matrix"/>
				<xsl:with-param name="lastpoint" select="$lastpoint"/>
				<xsl:with-param name="cursor" select="$cursor"/>
				<xsl:with-param name="startpoint" select="$startpoint"/>
			</xsl:call-template>				
		</xsl:if>
	</xsl:template>
	
	<!-- Dispatch processing to the needed path command implementation -->
    <xsl:template name="svg:path-command">
    	<xsl:param name="cmd"/>
    	<xsl:param name="lastpoint"/>
    	<xsl:param name="list"/>
    	<xsl:param name="matrix"/>
    	<xsl:param name="cursor"/>
    	<xsl:param name="cpoint2"/>
    	<xsl:param name="startpoint"/>
    	
		<!-- Keep track of our cursor, initialize with lastpoint if not set -->
    	<xsl:variable name="ctmp">
			<xsl:if test="not($cursor)">
				<xsl:value-of select="$lastpoint"/>
			</xsl:if>
			<xsl:if test="$cursor">
				<xsl:value-of select="$cursor"/>
			</xsl:if>
		</xsl:variable>
	
    	<xsl:message terminate="no">svg:path-command::Path command <xsl:value-of select="$cmd"/></xsl:message>
		<!-- Depending on command, process further -->
		<xsl:choose>
			<!-- Execute simple moveto path -->
			<xsl:when test="$cmd='m' or $cmd='M'">
				<xsl:call-template name="svg:path-command-m">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>
					<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>
			<!-- Execute bezier curve path -->
			<xsl:when test="$cmd='c' or $cmd='C'">
				<xsl:call-template name="svg:path-command-c">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>
			<!-- Execute smooth bezier curve path -->
			<xsl:when test="$cmd='s' or $cmd='S'">
				<xsl:call-template name="svg:path-command-s">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="cpoint2" select="$cpoint2"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>			
			<!-- Execute line command -->
			<xsl:when test="$cmd='l' or $cmd='L'">
				<xsl:call-template name="svg:path-command-l">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>
			<!-- Execute vertical line command -->
			<xsl:when test="$cmd='v' or $cmd='V'">
				<xsl:call-template name="svg:path-command-v">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>
			<!-- Execute horizontal line command -->
			<xsl:when test="$cmd='h' or $cmd='H'">
				<xsl:call-template name="svg:path-command-h">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>
			<!-- Execute close path command -->
			<xsl:when test="$cmd='z'">
				<xsl:call-template name="svg:path-command-z">
					<xsl:with-param name="cmd" select="$cmd"/>
					<xsl:with-param name="list" select="$list"/>
					<xsl:with-param name="matrix" select="$matrix"/>			
			    	<xsl:with-param name="lastpoint" select="$lastpoint"/>
			    	<xsl:with-param name="cursor" select="$ctmp"/>
			    	<xsl:with-param name="startpoint" select="$startpoint"/>
				</xsl:call-template>
			</xsl:when>			
		</xsl:choose>	
    </xsl:template>	

	<!-- Process SVG paths - starts with a list of coordinates and commands
	     will branch out to the different path-command implementations and
	     recurse until the complete path is consumed.
	     Will track a cursor in order to process relative coordinates.
	  -->
    <xsl:template match="svg:path">
    	<xsl:message terminate="no">Path <xsl:value-of select="@id"/></xsl:message>

	<!-- Process colors and other style attributes -->
	<xsl:variable name="pathstyle">
		<xsl:if test="@style"><xsl:value-of select="@style"/></xsl:if>
		<xsl:if test="@class">
			<xsl:for-each select="tokenize(normalize-space(@class),'\s+')">
				<xsl:variable name="classid" select="concat('.', normalize-space(.))"/>
				<xsl:value-of select="$styles/entry[@key=$classid]"/>					
			</xsl:for-each>
		</xsl:if>			
	</xsl:variable> 
    	<xsl:variable name="fill" select="substring-before(substring-after($pathstyle,'fill:#'),';')"/>
    	<xsl:variable name="stroke" select="substring-before(substring-after($pathstyle,'stroke:#'),';')"/>
    	<xsl:message terminate="no">Path-fill   <xsl:value-of select="$fill"/></xsl:message>
	<xsl:message terminate="no">Path-stroke <xsl:value-of select="$stroke"/></xsl:message>
	<xsl:if test="$fill">
		<xsl:variable name="pen">
			<xsl:call-template name="rgb2pen">
				<xsl:with-param name="rgb" select="$fill"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-selectpen">
			<xsl:with-param name="number" select="$pen"/>
		</xsl:call-template>
	</xsl:if>
	<xsl:if test="not($fill)">
		<xsl:call-template name="hpgl-selectpen">
			<xsl:with-param name="number" select="1"/>
		</xsl:call-template>		
	</xsl:if>

	<!-- Find the points vector and optional transformation matrix -->
	<xsl:variable name="path1" select="replace(@d, '(-)', ',$1')"/>
	<xsl:message terminate="no">Path1 <xsl:value-of select="$path1"/></xsl:message>
	<xsl:variable name="path2" select="replace($path1, '([a-zA-Z])', ' $1 ')"/>
	<xsl:message terminate="no">Path2 <xsl:value-of select="$path2"/></xsl:message>
	<xsl:variable name="path3" select="replace($path2, ' ,', ' ')"/>
	<xsl:message terminate="no">Path3 <xsl:value-of select="$path3"/></xsl:message>
	<xsl:variable name="path4" select="replace($path3, '([-0-9\.]+,[-0-9\.]+)', ' $1 ')"/>
	<xsl:message terminate="no">Path4 <xsl:value-of select="$path4"/></xsl:message>
	<xsl:variable name="path5" select="normalize-space(replace($path4, ' , ', ' '))"/>
	<xsl:message terminate="no">Path5 <xsl:value-of select="$path5"/></xsl:message>
					
	<xsl:variable name="list" select="tokenize($path5, ' ')"/>
    	<!-- xsl:variable name="matrix" select="head(tokenize(normalize-space(concat(substring-before(substring-after(@transform,'matrix('),')'), ' ', $idmatrix)), ' '))"/ -->
    	<xsl:variable name="matrix">
			<xsl:call-template name="matrix-create">
				<xsl:with-param name="from" select="@transform"/>
			</xsl:call-template>
    	</xsl:variable>    	
    	<xsl:variable name="cmd" select="head($list)"/>    	
    	<!-- Process the command -->
		<xsl:call-template name="svg:path-command">
			<xsl:with-param name="lastpoint" select="0.0,0.0"/>
			<xsl:with-param name="cmd" select="$cmd"/>
			<xsl:with-param name="list" select="tail($list)"/>
			<xsl:with-param name="matrix" select="$matrix"/>			
		</xsl:call-template>
    </xsl:template>
    
    <!-- Process single lines line class="st4" x1="627.2" y1="605.9" x2="627.2" y2="805.4" -->
    <xsl:template match="svg:line">
        <!-- Process color -->
    	<xsl:variable name="color" select="substring-before(substring-after(@style,'stroke:#'),';')"/>
    	<xsl:message terminate="no">Color <xsl:value-of select="$color"/></xsl:message>
		<xsl:if test="$color">
			<xsl:variable name="pen">
				<xsl:call-template name="rgb2pen">
					<xsl:with-param name="rgb" select="$color"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="$pen"/>
			</xsl:call-template>
		</xsl:if>
    	<xsl:variable name="point1" select="string-join((@x1|@y1), ',')"/>	
    	<xsl:variable name="point2" select="string-join((@x2|@y2), ',')"/>		

    	<xsl:message terminate="no">Line from <xsl:value-of select="$point1"/> to <xsl:value-of select="$point2"/> </xsl:message>
    	<xsl:variable name="matrix">
			<xsl:call-template name="matrix-create">
				<xsl:with-param name="from" select="@transform"/>
			</xsl:call-template>
    	</xsl:variable>
    	<xsl:variable name="point1Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$point1"/>
			</xsl:call-template>
		</xsl:variable>
    	<xsl:variable name="point2Tx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$point2"/>
			</xsl:call-template>
		</xsl:variable>	
    	<xsl:message terminate="no">Line from <xsl:value-of select="$point1Tx"/> to <xsl:value-of select="$point2Tx"/> </xsl:message>		
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="normalize-space($point1Tx)"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-pendown-point">
			<xsl:with-param name="to" select="normalize-space($point2Tx)"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-penup"/>
    </xsl:template>
    
    <!-- Process polylines -->
    <xsl:template match="svg:polyline">
        <!-- Process color -->
    	<xsl:variable name="color" select="substring-before(substring-after(@style,'stroke:#'),';')"/>
    	<xsl:message terminate="no">Color <xsl:value-of select="$color"/></xsl:message>
		<xsl:if test="$color">
			<xsl:variable name="pen">
				<xsl:call-template name="rgb2pen">
					<xsl:with-param name="rgb" select="$color"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="$pen"/>
			</xsl:call-template>
		</xsl:if>
    	<xsl:variable name="firstpoint" select="substring-before(@points,' ')"/>
    	<xsl:variable name="pointlist" select="tokenize(substring-after(@points,' '), ' ')"/>
    	<xsl:variable name="matrix" select="substring-before(substring-after(@transform,'matrix('),')')"/>
    	<xsl:variable name="transform" select="insert-before($idmatrix, 0, $matrix)"/>
    	<xsl:variable name="firstpointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$transform[1]"/>
				<xsl:with-param name="v" select="$firstpoint"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="normalize-space($firstpointTx)"/>
		</xsl:call-template>
		<xsl:for-each select="$pointlist">
			<xsl:variable name="ptmp">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$transform[1]"/>
					<xsl:with-param name="v" select="."/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:if test="normalize-space($ptmp)!='NaN,NaN'">
				<xsl:call-template name="hpgl-pendown-point">
					<xsl:with-param name="to" select="normalize-space($ptmp)"/>
				</xsl:call-template>
			</xsl:if>
		</xsl:for-each>
		<xsl:call-template name="hpgl-penup"/>
    </xsl:template>
    
    <!-- Process polygons -->
    <xsl:template match="svg:polygon">
	<!-- Process colors and other style attributes -->
	<xsl:variable name="pathstyle">
		<xsl:if test="@style"><xsl:value-of select="@style"/></xsl:if>
		<xsl:if test="@class">
			<xsl:for-each select="tokenize(normalize-space(@class),'\s+')">
				<xsl:variable name="classid" select="concat('.', normalize-space(.))"/>
				<xsl:value-of select="$styles/entry[@key=$classid]"/>					
			</xsl:for-each>
		</xsl:if>			
	</xsl:variable> 
    	<xsl:variable name="fill" select="substring-before(substring-after($pathstyle,'fill:#'),';')"/>
    	<xsl:variable name="stroke" select="substring-before(substring-after($pathstyle,'stroke:#'),';')"/>
    	<xsl:message terminate="no">Path-fill   <xsl:value-of select="$fill"/></xsl:message>
	<xsl:message terminate="no">Path-stroke <xsl:value-of select="$stroke"/></xsl:message>
	<xsl:if test="$fill">
		<xsl:variable name="pen">
			<xsl:call-template name="rgb2pen">
				<xsl:with-param name="rgb" select="$fill"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-selectpen">
			<xsl:with-param name="number" select="$pen"/>
		</xsl:call-template>
	</xsl:if>
	<xsl:if test="not($fill)">
		<xsl:call-template name="hpgl-selectpen">
			<xsl:with-param name="number" select="1"/>
		</xsl:call-template>		
	</xsl:if>
    	<xsl:variable name="firstpoint" select="substring-before(@points,' ')"/>
    	<xsl:variable name="pointlist" select="tokenize(substring-after(@points,' '), ' ')"/>    	
    	<xsl:variable name="matrix" select="substring-before(substring-after(@transform,'matrix('),')')"/>
    	
 	    <xsl:variable name="matrix">
			<xsl:call-template name="matrix-create">
				<xsl:with-param name="from" select="@transform"/>
			</xsl:call-template>
    	</xsl:variable>    	
    	<xsl:variable name="firstpointTx">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$firstpoint"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="normalize-space($firstpointTx)"/>
		</xsl:call-template>
		<xsl:for-each select="$pointlist">
			<xsl:variable name="ptmp">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="."/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:if test="normalize-space($ptmp)!='NaN,NaN'">
				<xsl:call-template name="hpgl-pendown-point">
					<xsl:with-param name="to" select="normalize-space($ptmp)"/>
				</xsl:call-template>				
			</xsl:if>
		</xsl:for-each>
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="normalize-space($firstpointTx)"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-penup"/>		
    </xsl:template>
    
    <!-- Process text -->
    <xsl:template match="svg:text">
    	<xsl:message terminate="no">Text Styles <xsl:value-of select="$styles"/></xsl:message>
    	<!-- Process color and font size-->
		<!-- populate a textstyle variable depending on if there is a style or class attribute -->
		<xsl:variable name="textstyle">
			<xsl:if test="@style"><xsl:value-of select="@style"/></xsl:if>
			<xsl:if test="@class">
				<xsl:for-each select="tokenize(normalize-space(@class),'\s+')">
					<xsl:variable name="classid" select="concat('.', normalize-space(.))"/>
					<xsl:value-of select="$styles/entry[@key=$classid]"/>
					<xsl:message terminate="no">Text class |<xsl:value-of select="$classid"/>|</xsl:message>
				</xsl:for-each>
			</xsl:if>			
		</xsl:variable> 
		<xsl:message terminate="no">Text Style combined <xsl:value-of select="$textstyle"/></xsl:message>
    	<xsl:variable name="fontsize" select="replace(substring-before(substring-after($textstyle,'font-size:'),';'), 'px', '')"/>
    	<xsl:variable name="fill" select="substring-before(substring-after($textstyle,'fill:#'),';')"/>
    	<xsl:variable name="fontfamily" select="substring-before(substring-after($textstyle,'font-family:'),';')"/>
		<xsl:message terminate="no">Text Label <xsl:value-of select="."/></xsl:message>
		<xsl:message terminate="no">Text Size  <xsl:value-of select="$fontsize"/></xsl:message>
    	<xsl:message terminate="no">Text Color <xsl:value-of select="$fill"/></xsl:message>

		<xsl:if test="$fill">
			<xsl:variable name="pen">
				<xsl:call-template name="rgb2pen">
					<xsl:with-param name="rgb" select="$fill"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="$pen"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="not($fill)">
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="1"/>
			</xsl:call-template>		
		</xsl:if>
		
    	<xsl:variable name="size" select="number($fontsize)"/>  <!--  * $px2cm probably needed for point sizes -->
    	<xsl:variable name="matrix">
			<xsl:call-template name="matrix-create">
				<xsl:with-param name="from" select="@transform"/>
			</xsl:call-template>
    	</xsl:variable>
    	
    	<xsl:variable name="X">
			<xsl:if test="@x">
				<xsl:value-of select="@x"/>
			</xsl:if>
			<xsl:if test="not(@x)">
				<xsl:text>0</xsl:text>
			</xsl:if>
		</xsl:variable>
    	<xsl:variable name="Y">
			<xsl:if test="@y">
				<xsl:value-of select="@y"/>
			</xsl:if>
			<xsl:if test="not(@y)">
				<xsl:text>0</xsl:text>
			</xsl:if>
		</xsl:variable>
		
    	<xsl:variable name="vector" select="string-join(($X|$Y), ',')"/>
		<xsl:message terminate="no">Text Transform |<xsl:value-of select="$matrix"/>|</xsl:message>
    	<xsl:variable name="point">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$vector"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:message terminate="no">Text vector in |<xsl:value-of select="$vector"/>|</xsl:message>
		<xsl:message terminate="no">Text vector out|<xsl:value-of select="$point"/>|</xsl:message>
		<xsl:variable name="vector_di" select="'1.0,0.0'"/>
    	<xsl:variable name="point_di">
			<xsl:choose>
			  <xsl:when test="contains(@transform,'rotate')">
				<xsl:call-template name="matrix-transform">
					<xsl:with-param name="m" select="$matrix"/>
					<xsl:with-param name="v" select="$vector_di"/>
				</xsl:call-template>
			  </xsl:when>
			  <xsl:otherwise>
				<xsl:value-of select="$vector_di"/>
			  </xsl:otherwise>
			</xsl:choose>    		
		</xsl:variable>
	    <xsl:call-template name="hpgl-text-direction">
	    	<xsl:with-param name="vector" select="$point_di"/>
	    </xsl:call-template>
	    <!-- see if we need to plot italic text -->
	    <xsl:choose>
	    	<xsl:when test="contains(upper-case($fontfamily),'ITALIC')">
	    		<xsl:text>SL0.3;</xsl:text>
	    	</xsl:when>
	    	<xsl:otherwise>
	    		<xsl:text>SL0;</xsl:text>
	    	</xsl:otherwise>
	    </xsl:choose>
	    <!-- Test if we have tspans, then loop through -->
	    <!-- Otherwise, just render the text -->
		<xsl:choose>
			<xsl:when test="*">	    
   				<xsl:for-each select="*">
   					<xsl:message terminate="no">TSpan <xsl:value-of select="."/></xsl:message>
   								
						<xsl:variable name="X">
							<xsl:if test="@x">
								<xsl:value-of select="@x"/>
							</xsl:if>
							<xsl:if test="not(@x)">
								<xsl:text>0</xsl:text>
							</xsl:if>
						</xsl:variable>
						<xsl:variable name="Y">
							<xsl:if test="@y">
								<xsl:value-of select="@y"/>
							</xsl:if>
							<xsl:if test="not(@y)">
								<xsl:text>0</xsl:text>
							</xsl:if>
						</xsl:variable>
							<xsl:variable name="textstyle">
								<xsl:if test="@style"><xsl:value-of select="@style"/></xsl:if>
								<xsl:if test="@class">
									<xsl:for-each select="tokenize(normalize-space(@class),'\s+')">
										<xsl:variable name="classid" select="concat('.', normalize-space(.))"/>
										<xsl:value-of select="$styles/entry[@key=$classid]"/>
										<xsl:message terminate="no">Text class |<xsl:value-of select="$classid"/>|</xsl:message>
									</xsl:for-each>
								</xsl:if>			
						</xsl:variable> 
						<xsl:variable name="fontsize" select="replace(substring-before(substring-after($textstyle,'font-size:'),';'), 'px', '')"/>
						<xsl:variable name="size" select="number($fontsize)"/>
						<xsl:variable name="vector" select="string-join(($X|$Y), ',')"/>
						<xsl:message terminate="no">TSPan Transform |<xsl:value-of select="$matrix"/>|</xsl:message>
						<xsl:variable name="point">
							<xsl:call-template name="matrix-transform">
								<xsl:with-param name="m" select="$matrix"/>
								<xsl:with-param name="v" select="$vector"/>
							</xsl:call-template>
						</xsl:variable>
						<xsl:call-template name="hpgl-text-size">
							<xsl:with-param name="size" select="$size"/>
						</xsl:call-template>						
						<xsl:call-template name="hpgl-plotabs">
							<xsl:with-param name="to" select="$point"/>
						</xsl:call-template>						
						<xsl:call-template name="hpgl-text-label">
							<xsl:with-param name="text" select="."/>
						</xsl:call-template>

				</xsl:for-each>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="hpgl-text-size">
					<xsl:with-param name="size" select="$size"/>
				</xsl:call-template>
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$point"/>
				</xsl:call-template>
				<xsl:call-template name="hpgl-text-label">
					<xsl:with-param name="text" select="."/>
				</xsl:call-template>
			</xsl:otherwise>
	    </xsl:choose>

    </xsl:template>

	<!-- Process ellipse -->
    <xsl:template match="svg:ellipse">
    	<!-- Process color -->
    	<xsl:variable name="color" select="substring-before(substring-after(@style,'stroke:#'),';')"/>
    	<xsl:message terminate="no">Color <xsl:value-of select="$color"/></xsl:message>
		<xsl:if test="$color">
			<xsl:variable name="pen">
				<xsl:call-template name="rgb2pen">
					<xsl:with-param name="rgb" select="$color"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="$pen"/>
			</xsl:call-template>
		</xsl:if>
    
    	<xsl:variable name="matrix">
			<xsl:call-template name="matrix-create">
				<xsl:with-param name="from" select="@transform"/>
			</xsl:call-template>
    	</xsl:variable>
    	<xsl:variable name="vector" select="concat(@cx,',',@cy)"/>	
    	<xsl:variable name="point">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$vector"/>
			</xsl:call-template>
		</xsl:variable>	
		<xsl:variable name="dx" select="number(@cx - @rx)"/>	
    	<xsl:variable name="vector2" select="concat($dx,',',@cy)"/>	
    	<xsl:variable name="point2">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$vector2"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="$point2"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-pendown"/>
		<xsl:call-template name="hpgl-arc-abs">
			<xsl:with-param name="endpoint" select="$point"/>
			<xsl:with-param name="angle" select="'360'"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-penup"/>
    </xsl:template>

	<!-- Process circle -->
    <xsl:template match="svg:circle">
    	<!-- Process color -->
    	<xsl:variable name="color" select="substring-before(substring-after(@style,'stroke:#'),';')"/>
    	<xsl:message terminate="no">Color <xsl:value-of select="$color"/></xsl:message>
		<xsl:if test="$color">
			<xsl:variable name="pen">
				<xsl:call-template name="rgb2pen">
					<xsl:with-param name="rgb" select="$color"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="$pen"/>
			</xsl:call-template>
		</xsl:if>
    	<xsl:variable name="matrix">
			<xsl:call-template name="matrix-create">
				<xsl:with-param name="from" select="@transform"/>
			</xsl:call-template>
    	</xsl:variable>
    	<xsl:variable name="vector" select="concat(@cx,',',@cy)"/>	
    	<xsl:variable name="point">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$vector"/>
			</xsl:call-template>
		</xsl:variable>	
		<xsl:variable name="dx" select="number(@cx - @r)"/>	
    	<xsl:variable name="vector2" select="concat($dx,',',@cy)"/>	
    	<xsl:variable name="point2">
			<xsl:call-template name="matrix-transform">
				<xsl:with-param name="m" select="$matrix"/>
				<xsl:with-param name="v" select="$vector2"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:call-template name="hpgl-plotabs">
			<xsl:with-param name="to" select="$point2"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-pendown"/>
		<xsl:call-template name="hpgl-arc-abs">
			<xsl:with-param name="endpoint" select="$point"/>
			<xsl:with-param name="angle" select="'360'"/>
		</xsl:call-template>
		<xsl:call-template name="hpgl-penup"/>				
    </xsl:template>

	<!-- Process rectangle -->
    <xsl:template match="svg:rect">
    	<!-- Process color -->
    	<xsl:variable name="color" select="substring-before(substring-after(@style,'stroke:#'),';')"/>
    	<xsl:variable name="fill" select="@opacity"/>
    	
		<xsl:variable name="fillstyle">
			<xsl:if test="@style"><xsl:value-of select="@style"/></xsl:if>
			<xsl:if test="@class">
				<xsl:for-each select="tokenize(normalize-space(@class),'\s+')">
					<xsl:variable name="classid" select="concat('.', normalize-space(.))"/>
					<xsl:value-of select="$styles/entry[@key=$classid]"/>
					<xsl:message terminate="no">style class |<xsl:value-of select="$classid"/>|</xsl:message>
				</xsl:for-each>
			</xsl:if>
		</xsl:variable>
		<xsl:message terminate="no">RECT <xsl:value-of select="$fillstyle"/></xsl:message>
		<xsl:message terminate="no">Style combined <xsl:value-of select="$fillstyle"/></xsl:message>
    	<xsl:variable name="fill" select="substring-before(substring-after($fillstyle,'fill:#'),';')"/>
    	<xsl:variable name="opacity" select="substring-before(substring-after($fillstyle,'opacity:'),';')"/>
    	<xsl:message terminate="no">Rect Fill <xsl:value-of select="$fill"/></xsl:message>
   		<xsl:message terminate="no">Rect Opac <xsl:value-of select="$opacity"/></xsl:message>
    	
    	<!-- Determine pen from fill color -->
    	<xsl:message terminate="no">Color <xsl:value-of select="$color"/></xsl:message>
		<xsl:if test="$fill">
			<xsl:variable name="pen">
				<xsl:call-template name="rgb2pen">
					<xsl:with-param name="rgb" select="$fill"/>
				</xsl:call-template>
			</xsl:variable>
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="$pen"/>
			</xsl:call-template>
		</xsl:if>
		<xsl:if test="not($fill)">
			<xsl:call-template name="hpgl-selectpen">
				<xsl:with-param name="number" select="1"/>
			</xsl:call-template>		
		</xsl:if>
		<!-- if a transformation is given, construct rect from lines -->
		<!-- else use built in HPGL command -->
		<xsl:choose>
			<xsl:when test="not(@transform)">
		    	<xsl:variable name="p1" select="concat(@x,',',@y)"/>
				<xsl:variable name="x2" select="number(@x) + number(@width)"/>	
				<xsl:variable name="y2" select="number(@y) + number(@height)"/>	
		    	<xsl:variable name="p2" select="concat($x2,',',$y2)"/>
		    	<!-- Still need to create the matrix to get the base transformations -->
		    	<xsl:variable name="matrix">
					<xsl:call-template name="matrix-create">
						<xsl:with-param name="from" select="@transform"/>
					</xsl:call-template>
		    	</xsl:variable>
		    	<xsl:variable name="p1T">
					<xsl:call-template name="matrix-transform">
						<xsl:with-param name="m" select="$matrix"/>
						<xsl:with-param name="v" select="$p1"/>
					</xsl:call-template>
				</xsl:variable>	
		    	<xsl:variable name="p2T">
					<xsl:call-template name="matrix-transform">
						<xsl:with-param name="m" select="$matrix"/>
						<xsl:with-param name="v" select="$p2"/>
					</xsl:call-template>
				</xsl:variable>
				<xsl:message terminate="no">Rect untransformed<xsl:value-of select="$p1"/> <xsl:value-of select="$p2"/></xsl:message>
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$p1T"/>
				</xsl:call-template>
				<xsl:call-template name="hpgl-pendown"/>
				<xsl:call-template name="hpgl-edge-abs">
					<xsl:with-param name="endpoint" select="$p2T"/>
					<xsl:with-param name="opacity" select="$opacity"/>
				</xsl:call-template>
				<xsl:call-template name="hpgl-penup"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:variable name="x2" select="number(@x) + number(@width)"/>	
				<xsl:variable name="y2" select="number(@y) + number(@height)"/>	
		    	<xsl:variable name="p1" select="concat(@x,',',@y)"/>
		    	<xsl:variable name="p2" select="concat($x2,',',@y)"/>
		    	<xsl:variable name="p3" select="concat($x2,',',$y2)"/>
		    	<xsl:variable name="p4" select="concat(@x,',',$y2)"/>

		    	<xsl:variable name="matrix">
					<xsl:call-template name="matrix-create">
						<xsl:with-param name="from" select="@transform"/>
					</xsl:call-template>
		    	</xsl:variable>

		    	<xsl:variable name="p1T">
					<xsl:call-template name="matrix-transform">
						<xsl:with-param name="m" select="$matrix"/>
						<xsl:with-param name="v" select="$p1"/>
					</xsl:call-template>
				</xsl:variable>	
		    	<xsl:variable name="p2T">
					<xsl:call-template name="matrix-transform">
						<xsl:with-param name="m" select="$matrix"/>
						<xsl:with-param name="v" select="$p2"/>
					</xsl:call-template>
				</xsl:variable>	
		    	<xsl:variable name="p3T">
					<xsl:call-template name="matrix-transform">
						<xsl:with-param name="m" select="$matrix"/>
						<xsl:with-param name="v" select="$p3"/>
					</xsl:call-template>
				</xsl:variable>	
		    	<xsl:variable name="p4T">
					<xsl:call-template name="matrix-transform">
						<xsl:with-param name="m" select="$matrix"/>
						<xsl:with-param name="v" select="$p4"/>
					</xsl:call-template>
				</xsl:variable>	
				<xsl:message terminate="no">Rect <xsl:value-of select="$p1T"/> <xsl:value-of select="$p2T"/> <xsl:value-of select="$p3T"/> <xsl:value-of select="$p4T"/></xsl:message>
				
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$p1T"/>
				</xsl:call-template>				
				<xsl:call-template name="hpgl-pendown"/>
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$p2T"/>
				</xsl:call-template>				
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$p3T"/>
				</xsl:call-template>				
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$p4T"/>
				</xsl:call-template>				
				<xsl:call-template name="hpgl-plotabs">
					<xsl:with-param name="to" select="$p1T"/>
				</xsl:call-template>				
				<xsl:call-template name="hpgl-penup"/>
			</xsl:otherwise>
		</xsl:choose>
    </xsl:template>
	
	<!-- Catches the clipPath element to eliminate unwanted paths -->
	<xsl:template match="svg:clipPath">
		<xsl:message terminate="no">Skipping clipPath for now:<xsl:value-of select="name()"/></xsl:message>
	</xsl:template>
	
	<!-- Catches the flowroot element to eliminate unwanted rects -->
	<xsl:template match="svg:flowRoot">
		<xsl:message terminate="no">Skipping flowroot for now:<xsl:value-of select="name()"/></xsl:message>
	</xsl:template>
	
    <!-- Catch all rule to fire on un-matched elements - ideally should not appear -->
    <xsl:template match="*">
        <xsl:message terminate="no">WARNING: Unmatched element:<xsl:value-of select="name()"/></xsl:message>
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>
