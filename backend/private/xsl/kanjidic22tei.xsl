<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.tei-c.org/ns/1.0" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xd="http://www.pnp-software.com/XSLTdoc"   exclude-result-prefixes="xs xd">
    
    <xsl:output 
        method="xml" 
        version="1.0" 
        encoding="UTF-8" 
        indent="yes" 
        doctype-system="freedict-P5.dtd"/>
    
    <xd:doc type="stylesheet">
    </xd:doc>
    
    <xsl:param name="targetlang"/>
    
    <xsl:template match="kanjidic2">
        <TEI xmlns="http://www.tei-c.org/ns/1.0" version="5.0">
            <text>
                <body>
                    <xsl:text>&#xa;</xsl:text>
                    <xsl:for-each select="character">	
                        <xsl:if test="reading_meaning/rmgroup/meaning[($targetlang = 'en' and not (@m_lang)) or @m_lang = $targetlang]">
                            <entry>
                                <xsl:apply-templates select="literal"/>
                                <xsl:apply-templates select="codepoint"/>
                                <xsl:apply-templates select="radical"/>
                                <xsl:apply-templates select="misc"/>
                                <xsl:apply-templates select="dic_number"/>
                                <xsl:apply-templates select="query_code"/>
                                <xsl:apply-templates select="reading_meaning"/>
                            </entry>
                            <xsl:text>&#xa;</xsl:text>
                        </xsl:if>
                    </xsl:for-each>  	
                </body>
            </text>
        </TEI>
    </xsl:template>
    
    <xsl:template match="header"></xsl:template>
    <xsl:template match="literal"><form type="k_ele"><orth><xsl:value-of select="."/></orth></form><xsl:text>&#xa;</xsl:text></xsl:template>
    
    <xsl:template match="codepoint"><!--<note type="codepoint"><xsl:apply-templates/></note><xsl:text>&#xa;</xsl:text>--></xsl:template>
    <xsl:template match="cp_value"><!--<note type="cp_value"><xsl:value-of select="."/></note>--></xsl:template>
    
    <xsl:template match="radical"><note type="radical"><xsl:apply-templates/></note><xsl:text>&#xa;</xsl:text></xsl:template>
    <xsl:template match="rad_value"><note type="rad_value"><xsl:value-of select="."/></note></xsl:template>
    
    <xsl:template match="misc"><note type="misc"><xsl:apply-templates/></note><xsl:text>&#xa;</xsl:text></xsl:template>
    <xsl:template match="grade"><note type="grade"><xsl:value-of select="."/></note></xsl:template>
    <xsl:template match="stroke_count"><note type="stroke_count"><xsl:value-of select="."/></note></xsl:template>
    <xsl:template match="variant"><note type="variant"><xsl:value-of select="."/></note></xsl:template>
    <xsl:template match="freq"><note type="freq"><xsl:value-of select="."/></note></xsl:template>
    <xsl:template match="rad_name"><note type="rad_name"><xsl:value-of select="."/></note></xsl:template>
    <xsl:template match="jlpt"><note type="jlpt"><xsl:value-of select="."/></note></xsl:template>
    
    
    <xsl:template match="dic_number"><!--<note type="dic_number"><xsl:apply-templates/></note><xsl:text>&#xa;</xsl:text>--></xsl:template>
    <xsl:template match="dic_ref"><!--<note type="dic_ref"><xsl:value-of select="."/></note>--></xsl:template>
    
    
    <xsl:template match="query_code"><note type="query_code"><xsl:apply-templates/></note><xsl:text>&#xa;</xsl:text></xsl:template>
    <xsl:template match="q_code"><note type="q_code"><xsl:value-of select="."/></note></xsl:template>
    
    <xsl:template match="reading_meaning"><xsl:apply-templates/><xsl:text>&#xa;</xsl:text></xsl:template>
    <xsl:template match="rm_group"><xsl:apply-templates/><xsl:text>&#xa;</xsl:text></xsl:template>
    
    <xsl:template match="reading">
        <xsl:if test="@r_type='ja_on' or @r_type='ja_kun'">
            <form type="r_ele">
                <xsl:element name="orth">
                    <xsl:attribute name="type"><xsl:value-of select="@r_type"/></xsl:attribute>
                    <xsl:value-of select="."/>
                </xsl:element>
            </form>
            <xsl:text>&#xa;</xsl:text>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="meaning">
        <xsl:if test="($targetlang='en' and not (@m_lang)) or @m_lang=$targetlang">            
            <xsl:element name="sense">
                <xsl:if test="@m_lang and @m_lang != ''">
                    <xsl:attribute name="lang">
                        <xsl:value-of select="@m_lang"/>
                    </xsl:attribute>
                </xsl:if>
                <cit type="trans">
                    <quote><xsl:value-of select="."/></quote>
                </cit>
            </xsl:element>
        </xsl:if> 
    </xsl:template>
    
    <xsl:template match="nanori"><form type="r_ele"><orth type='nanori'><xsl:value-of select="."/></orth></form></xsl:template>
    
</xsl:stylesheet>
