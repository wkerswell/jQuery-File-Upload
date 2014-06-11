<cfcomponent>

	<cffunction name="init" access="remote" returnformat="json">
	
		<cfscript>
			var options = 
			{	

				"uploadPath" 	: "files/uploads", //relitive to this file
				"uploadURL"		: "server/cf/files/uploads", //relitive the site root 
				"maxFileSize"	: 1 * 1024 * 1024,

				"watermark": 
				{
					"enabled" 		: true,
					"watermarkPath" : "watermark/watermark.png",
					"watermarkPossX": "right", //left,right or number
					"watermarkPossY": "bottom",  //top,bottom or number
					"transparency"	: 50  //top,bottom or number
				},

				"thumbnails": 
				{
				    "enabled" 		: true,
					"width" 		: "100",
					"height"		: "100",
					"uploadPath"	: "files/uploads/thumbs", //relitive to this file
					"uploadURL"		: "server/cf/files/uploads/thumbs", //relitive the site root 
					"interpolation" : "highestQuality",
					"quality" 		: 1,
					"watermark": 
					{
						"enabled" 		: true,
						"watermarkPath" : "watermark/watermarkSmall.png",
						"watermarkPossX": "right", //left,right or number
						"watermarkPossY": "bottom",  //top,bottom or number
						"transparency"	: 50  //top,bottom or number
					}
				}
			};

			if (GetHttpRequestData().method == "GET")
			{
				if (structKeyExists(url,"file") && url.file != "")
					return DELETE(options);
				
			} 
			else if (GetHttpRequestData().method EQ "POST")
			{
				return POST(options);
			}

		</cfscript> 

	</cffunction>

	<cffunction name="POST" access="private" returnformat="json">
		<cfargument name="options" type="struct" required="true">
		<cfset var result = 0 >
	
		
		<!--- get file info so we can check its size before we upload it --->
		<cfset fileInfo = GetFileInfo(form['files[]']) />
		<!--- get the name the file being uploaded so we can send it back to the ui to report any erros --->
		<cfset fileName = getClientFileName('files[]')>

		<cfif fileInfo.size lt options.maxFileSize>
			<!--- Upload the file --->
			<cffile action="upload" fileField="files[]" destination="#ExpandPath(options.uploadPath)#" nameConflict="makeUnique" result="upload">

			<!--- todo: could add another cfimage here to make any changed required to the main upload image. --->

		<cfelse>
			<!--- return error --->
			<cfreturn SerializeJSON(
				{"files": 
					[{
				    "name": "#fileName#",
				    "size": "#fileInfo.size#",
				    "error": "File is too large!"
				  }]
				}
			)>
		</cfif>
		
		

		<!--- Make a thumbnail  --->
		<cfif structKeyExists(options.thumbnails,"enabled") AND options.thumbnails.enabled EQ true>
			<cftry>
				<cfimage 
				    action = "resize"
				    height = "#options.thumbnails.width#"
				    width = "#options.thumbnails.height#"
				    source = "#ExpandPath(options.uploadPath)#/#upload.serverFile#"
				    destination = "#ExpandPath(options.thumbnails.uploadPath)#/thumb_#upload.serverfile#"
				    interpolation = "#options.thumbnails.interpolation#"
				    quality = "#options.thumbnails.quality#"> 	

			    <cfcatch type="any">
			    	<cfreturn SerializeJSON(
						{"files": 
							[{
						    "name": "#fileName#",
						    "error": "Could not create thumbnail!"
						  }]
						}
					)>
			  </cfcatch>
			</cftry>
		</cfif>

		<!--- Add water mark ---> 
		<cfif structKeyExists(options.watermark,"enabled") AND options.watermark.enabled EQ true>
			<cftry>
				
				<!--- Create two ColdFusion images from existing files. ---> 
				<cfimage source="#ExpandPath(options.uploadPath)#/#upload.serverFile#" name="objImage"> 
				<cfimage source="#ExpandPath(options.watermark.watermarkPath)#" name="objWatermark"> 

				<!--- Transparency of the watermark --->	
				<cfset ImageSetDrawingTransparency(objImage,options.watermark.transparency)> 

				<!--- Work out the watermark position based on the settings ---> 
				<cfset options.watermark.watermarkPossX = getWatermarkCoordinate("x",objImage.GetWidth(),objWatermark.GetWidth(),options.watermark.watermarkPossX)>
				<cfset options.watermark.watermarkPossY = getWatermarkCoordinate("y",objImage.GetHeight(),objWatermark.GetHeight(),options.watermark.watermarkPossY)>

				<!--- Add the watermark to the image --->
				<cfset ImagePaste(objImage,objWatermark, options.watermark.watermarkPossX, options.watermark.watermarkPossY )> 

				<!--- Write the result to a file. ---> 
				<cfimage source="#objImage#" destination="#ExpandPath(options.uploadPath)#/#upload.serverFile#" action="write" overwrite="yes"> 

				<!--- Add watermark for thumbnail --->
				<cfif structKeyExists(options.thumbnails.watermark,"enabled") AND options.thumbnails.watermark.enabled EQ true>
					<!--- See comments above for watermark--->
					<cfimage source="#ExpandPath(options.thumbnails.uploadPath)#/thumb_#upload.serverfile#" name="objImage"> 
					<cfimage source="#ExpandPath(options.thumbnails.watermark.watermarkPath)#" name="objWatermark"> 
					<cfset ImageSetDrawingTransparency(objImage,options.thumbnails.watermark.transparency)> 
					<cfset options.thumbnails.watermark.watermarkPossX = getWatermarkCoordinate("x",objImage.GetWidth(),objWatermark.GetWidth(),options.thumbnails.watermark.watermarkPossX)>
					<cfset options.thumbnails.watermark.watermarkPossY = getWatermarkCoordinate("y",objImage.GetHeight(),objWatermark.GetHeight(),options.thumbnails.watermark.watermarkPossY)>
					<cfset ImagePaste(objImage,objWatermark, options.thumbnails.watermark.watermarkPossX, options.thumbnails.watermark.watermarkPossY )> 
					<cfimage source="#objImage#" destination="#ExpandPath(options.thumbnails.uploadPath)#/thumb_#upload.serverfile#" action="write" overwrite="yes"> 
				</cfif>

			<cfcatch type="any">
		    	<cfreturn SerializeJSON(
					{"files": 
						[{
					    "name": "#fileName#",
					    "error": "Could not add watermark!"
					  }]
					}
				)>
			  </cfcatch>
			</cftry>
		</cfif>

		<!--- Create the json response  --->
		<cfscript>
			result = 
			{"files": 
				[{
				    "name":			upload.serverfile,
					"size":			upload.filesize,
					"url":			"#options.uploadURL#/#upload.serverFile#",
					"deleteUrl":	"server/cf/Upload.cfc?method=init&file=#upload.serverfile#",
					"deleteType":	"GET", //Used get rather than delete as was not working on my set up. 
					"thumbnailUrl" : "#options.thumbnails.uploadURL#/thumb_#upload.serverfile#"
				}]
			};
			
		</cfscript> 

		<cfreturn SerializeJSON(result)> 
	</cffunction>

	<cffunction name="DELETE" access="private" returnformat="json">
		<cfargument name="options" type="struct" required="true">
		<!--- Delete both the thumbnail and image --->
		<cftry>
			<cffile action="delete" file="#ExpandPath('#options.uploadPath#/#URL.file#')#">
			<cffile action="delete" file="#ExpandPath('#options.thumbnails.uploadPath#/thumb_#URL.file#')#">
		  <cfcatch type="any">
		  	<cfreturn SerializeJSON(
					{"files": 
						[{
					    "name": "#URL.file#",
					    "error": "Could not delete!"
					  }]
					}
				)>
		  </cfcatch>
		</cftry>

		<!--- Create the json response  --->
		<cfscript>
			var result = 
			{"files": 
				[{
				    "#URL.file#": true
				 }]
			};
							
		</cfscript> 

		<cfreturn SerializeJSON(result)>
	</cffunction>

	<cffunction name="getClientFileName" returntype="string" output="false" hint="This functions gets the name of the file being uploaded before its uploaded.">
	    <cfargument name="fieldName" required="true" type="string" hint="Name of the Form field" />

	    <cfset var tmpPartsArray = Form.getPartsArray() />

	    <cfif IsDefined("tmpPartsArray")>
	        <cfloop array="#tmpPartsArray#" index="local.tmpPart">
	            <cfif local.tmpPart.isFile() AND local.tmpPart.getName() EQ arguments.fieldName>
	                <cfreturn local.tmpPart.getFileName() />
	            </cfif>
	        </cfloop>
	    </cfif>

	    <cfreturn "" />
	</cffunction>

	<cffunction name="getWatermarkCoordinate" returntype="string" output="false" hint="This function will work out the coordinates for the watermark">
	    <cfargument name="plane" required="true" type="string" hint="X or Y" />
	    <cfargument name="objImage" required="true" type="string" hint="Image size in the plane" />
	    <cfargument name="objWatermark" required="true" type="string" hint="wartermark size in the plane" />
	    <cfargument name="coord" required="true" type="string" hint="coor supplied" />

	    <cfscript>
			if (arguments.plane == "y")
			{
				if (arguments.coord eq "bottom")
					return (objImage - objWatermark);
				else if (arguments.coord eq "top" )
					return 0;
				else
					return coord;
			}
			else if (arguments.plane eq "x")
			{
				if (arguments.coord eq "right")
					return (objImage - objWatermark);
				else if (arguments.coord eq "left")
					return 0;
				else
					return coord;
			}

		</cfscript>
	</cffunction>

</cfcomponent>