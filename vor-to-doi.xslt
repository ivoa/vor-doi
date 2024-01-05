<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:ri="http://www.ivoa.net/xml/RegistryInterface/v1.0"
    xmlns:vr="http://www.ivoa.net/xml/VOResource/v1.0"
    xmlns:oai="http://www.openarchives.org/OAI/2.0/"
    xmlns:d="http://datacite.org/schema/kernel-4"
    version="1.0">

    <!-- ############################################## Global behaviour -->

    <xsl:output method="xml"/>

    <!-- Don't spill the content of unknown elements. -->
    <xsl:template match="text()"/>

    <xsl:template match="ri:Resource">
      <d:resource xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://datacite.org/schema/kernel-4
          http://schema.datacite.org/meta/kernel-4/metadata.xsd">
        <d:identifier identifierType="DOI">
          <xsl:choose>
            <xsl:when test="starts-with(altIdentifier[1], 'doi:')">
              <xsl:value-of select="substring-after(altIdentifier, 'doi:')"/>
            </xsl:when>
            <xsl:when test="$doi_for_record">
              <xsl:value-of select="$doi_for_record"/>
            </xsl:when>
          </xsl:choose>
        </d:identifier>
        <d:creators>
          <xsl:apply-templates select="curation/creator"/>
        </d:creators>
        <d:titles>
          <xsl:apply-templates select="title"/>
        </d:titles>
        <xsl:apply-templates select="curation/publisher"/>
        <d:publicationYear>
          <xsl:value-of select="substring-before(@created, '-')"/>
        </d:publicationYear>
        <d:subjects>
          <xsl:apply-templates select="content/subject"/>
        </d:subjects>
        <d:contributors>
          <xsl:apply-templates select="curation/contact"/>
        </d:contributors>
        <xsl:call-template name="computeResourceType"/>
        <xsl:call-template name="alternateIdentifier"/>
        <d:relatedIdentifiers>
            <xsl:apply-templates select="content/relationship"/>
            <xsl:apply-templates select="content/source"/>
        </d:relatedIdentifiers>
        <d:formats>
          <xsl:apply-templates select="capability/interface/resultType"/>
        </d:formats>
        <xsl:apply-templates select="curation/version"/>
        <d:rightsList>
            <xsl:apply-templates select="rights"/>
        </d:rightsList>
        <d:descriptions>
          <xsl:apply-templates select="content/description"/>
        </d:descriptions>
      </d:resource>
    </xsl:template>


    <!-- ########################################### Individual elements -->

    <xsl:template match="creator">
      <d:creator>
        <d:creatorName>
          <xsl:value-of select="name"/>
        </d:creatorName>
      </d:creator>
    </xsl:template>

    <xsl:template match="title">
      <d:title><xsl:value-of select="."/></d:title>
    </xsl:template>

    <xsl:template match="publisher">
      <d:publisher><xsl:value-of select="."/></d:publisher>
    </xsl:template>

    <xsl:template match="subject">
      <d:subject><xsl:value-of select="."/></d:subject>
    </xsl:template>

    <xsl:template match="resultType">
      <d:format><xsl:value-of select="."/></d:format>
    </xsl:template>

    <xsl:template match="version">
      <d:version><xsl:value-of select="."/></d:version>
    </xsl:template>

    <xsl:template match="rights">
      <d:rights>
        <xsl:if test="@rightsURI">
          <xsl:attribute name="rightsURI">
            <xsl:value-of select="@rightsURI"/>
          </xsl:attribute>
        </xsl:if>
        <xsl:value-of select="."/>
      </d:rights>
    </xsl:template>

    <xsl:template match="description">
      <d:description descriptionType="Abstract">
        <xsl:value-of select="."/>
      </d:description>
    </xsl:template>

    <!-- ignore everything complex in TAPRegExt -->
    <xsl:template match="language"/>

    <xsl:template match="relatedResource[@ivo-id]">
        <xsl:param name="relationshipType"/>
        <xsl:if test="$relationshipType!=''">
            <d:relatedIdentifier relatedIdentifierType="URL">
                <xsl:attribute name="relationType">
                    <xsl:value-of select="$relationshipType"/>
                </xsl:attribute>
                <xsl:value-of select="@ivo-id"/>
            </d:relatedIdentifier>
        </xsl:if>
    </xsl:template>

    <xsl:template match="relatedResource[@altIdentifier]">
        <xsl:param name="relationshipType"/>
        <xsl:if test="$relationshipType!=''">
            <d:relatedIdentifier relatedIdentifierType="DOI">
                <xsl:attribute name="relationType">
                    <xsl:value-of select="$relationshipType"/>
                </xsl:attribute>
                <xsl:value-of select="@altIdentifier"/>
            </d:relatedIdentifier>
        </xsl:if>
    </xsl:template>

    <!-- Translate three VOResource 1.0 relation types; note that
      IsServedBy isn't supported by DataCite yet, but it's so important
      I'm willing to produce broken records.
      -->
    <xsl:template match="relationship[relationshipType='mirror-of']">
      <xsl:apply-templates>
          <xsl:with-param name="relationshipType"
            >IsIdenticalTo</xsl:with-param>>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="relationship[relationshipType='derived-from']">
      <xsl:apply-templates>
        <xsl:with-param name="relationshipType"
          >IsDerivedFrom</xsl:with-param>>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="relationship[relationshipType='served-by']">
      <xsl:apply-templates>
        <xsl:with-param name="relationshipType"
          >IsServedBy</xsl:with-param>>
      </xsl:apply-templates>
    </xsl:template>

    <!-- pull through RDF relationship_type (it would be cool to
      take these from http://www.ivoa.net/rdf/voresource/relationship_type
      by program -->
    <xsl:template match="relationship[relationshipType='Cites']
      | relationship[relationshipType='Continues']
      | relationship[relationshipType='HasPart']
      | relationship[relationshipType='IsContinuedBy']
      | relationship[relationshipType='IsDerivedFrom']
      | relationship[relationshipType='IsIdenticalTo']
      | relationship[relationshipType='IsNewVersionOf']
      | relationship[relationshipType='IsPartOf']
      | relationship[relationshipType='isPreviousVersionOf']
      | relationship[relationshipType='IsServedBy']
      | relationship[relationshipType='IsServiceFor']
      | relationship[relationshipType='IsSourceOf']
      | relationship[relationshipType='IsSupplementTo']
      | relationship[relationshipType='IsSupplementedBy']
      ">
      <xsl:apply-templates>
        <xsl:with-param name="relationshipType"
          ><xsl:value-of select="relationshipType"/></xsl:with-param>>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="curation/contact">
      <d:contributor contributorType="ContactPerson">
        <d:contributorName>
          <xsl:value-of select="name"/>
          <xsl:if test="email">
            <xsl:text> &lt;</xsl:text>
            <xsl:value-of select="email"/>
            <xsl:text>&gt;</xsl:text>
          </xsl:if>
        </d:contributorName>
      </d:contributor>
    </xsl:template>

    <xsl:template match="content/source[@format='bibcode']">
      <d:relatedIdentifier relatedIdentifierType="bibcode"
          relationType="IsSupplementTo"
        ><xsl:value-of select="."/></d:relatedIdentifier>
    </xsl:template>

    <!-- ######################## named templates for more complex logic -->

    <xsl:template name="computeResourceType">
      <d:resourceType>
        <xsl:attribute name="resourceTypeGeneral">
          <xsl:choose>
            <xsl:when test="@xsi:type='vs:DataService'
                or @xsi:type='vs:CatalogService'
                or @xsi:type='vs:TableService'
                or @xsi:type='vr:Service'"
              >Service</xsl:when>
            <xsl:when test="@xsi:type='vs:DataCollection'"
              >Collection</xsl:when>
            <xsl:when test="@xsi:type='vstd:Standard'"
              >Text</xsl:when>
            <xsl:when test="@xsi:type='doc:Document'"
              >Text</xsl:when>
            <xsl:otherwise>Other</xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>

        <!-- to guess what the service might be, we look at the first
        capability's standardID.  This is quite heuristic, but anything
        fancier is complicated given we have to come up with at most one
        term and we don't have case-insensitive comparisons in XPath. -->
        <xsl:variable name="normalizedID" select="translate(
          capability[@standardID]/@standardID,
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
          'abcdefghijklmnopqrstuvwxyz')"/>
        <xsl:choose>
          <xsl:when
            test="$normalizedID='ivo://ivoa.net/std/conesearch'"
            >AstroObjects</xsl:when>
          <xsl:when
            test="$normalizedID='ivo://ivoa.net/std/sia'"
            >AstroImage</xsl:when>
          <xsl:when
            test="$normalizedID='ivo://ivoa.net/std/ssa'"
            >Spectrum</xsl:when>
          <xsl:when
            test="$normalizedID='ivo://ivoa.net/std/slap'"
            >SpectralLines</xsl:when>
          <xsl:when
            test="$normalizedID='ivo://ivoa.net/std/tap'"
            >AstroData</xsl:when>
        </xsl:choose>
      </d:resourceType>
    </xsl:template>

    <xsl:template name="alternateIdentifier">
      <d:alternateIdentifiers>
        <d:alternateIdentifier alternateIdentifierType="ivoid">
          <xsl:value-of select="identifier"/>
        </d:alternateIdentifier>
      </d:alternateIdentifiers>
    </xsl:template>

</xsl:stylesheet>


<!-- vim:et:sw=2:sta
-->
