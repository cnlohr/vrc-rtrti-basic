Shader "Custom/rtrti-standard-dynamic"
{
    Properties
    {
		_EmissionTex ("Emission Texture", 2D) = "white" {}
		_MainTex("Main Texture", 2D) = "white" {}
		_NoiseTex( "Noise Texture", 2D) = "white" {}
		[HDR] _MainTexColor("Main Tex Color", Color) = ( 1, 1, 1, 1 )
		[HDR] _MainTexColorBoost("Main Tex Add", Color) = ( 0, 0, 0, 0)
		_Roughness("Roughness", 2D) = "white" {}
		_Metallicity("Metallicity", 2D) = "white" {}
		_CombinedRelfectionTextures("Combined Reflection Textures", 2D) = "white" {}
		_NumberOfCombinedTextures( "Number of Combined Textures", float ) = 6.0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_GeoTex ("Geometry", 2D) = "black" {}
		_DiffuseUse( "Diffuse Use", float ) = .1
		_DiffuseShift( "Diffuse Shift", float) = 0.0
		_MediaBrightness( "Media Brightness", float ) = 1.2
		_RoughnessIntensity( "Roughness Intensity", float ) = 3.0
		_RoughnessShift( "Roughness Shift", float ) = 0.0
		_NormalizeValue("Normalize Value", float) = 0.0
		_RoughAdj("Roughness Adjust", float) = 0.3
		_Flip("Flip Mirror Enable", float ) =0.0
		_MirrorPlace("Mirror Place", Vector ) = ( 0, 0, 0, 0)
		_MirrorScale("Mirror Enable", Vector ) = ( 0, 0, 0, 0)
		_MirrorRotation("Mirror Rotation", Vector ) = ( 0, 0, 0, 0)
		_OverrideReflection( "Override Reflection", float)=0.0
		_SkyboxBrightness("Skybox Brightness", float) = 1.0
		_AlbedoBoost("Albedo Boost", float) = 1.0
		_MetallicMux("Metallic Mux", float) = 1.0
		_MetallicShift("Metallic Shift", float) = 0.0
		_SmoothnessMux("Smooth Mux", float) = 1.0
		_SmoothnessShift("Smooth Shift", float) = 0.0
		[HDR] _Ambient("Ambient Color", Color) = (0.1,0.1,0.1,1.0)
		
		[Toggle(DEBUG_TRACE)] DEBUG_TRACE( "Debug Trace", float ) = 0.0
		[Toggle(_ENABLERT)] _ENABLERT( "Enable Ray Tracing", float ) = 1.0
		[Toggle(_ENABLESSR)] _ENABLESSR( "Enable SSR", float ) = 1.0
    }
    SubShader
    {
		Tags { "Queue"="Transparent-1" "RenderType"="Opaque"}

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard nometa

		#pragma multi_compile_local _  _ENABLESSR
		#pragma multi_compile_local _  _ENABLERT
		#pragma multi_compile_local _  DEBUG_TRACE

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 5.0
		
		#include "/Assets/cnlohr/Shaders/hashwithoutsine/hashwithoutsine.cginc"
#ifndef SHADER_TARGET_SURFACE_ANALYSIS
		#include "/Assets/vrc-rtrti/Shaders/ErrorSSR/SSR.cginc"
#else
		
#endif

		sampler2D _EmissionTex;
		sampler2D _BumpMap, _MainTex, _Roughness, _Metallicity;
		sampler2D _CombinedRelfectionTextures;
		sampler2D _GrabTexture;
#ifndef SHADER_TARGET_SURFACE_ANALYSIS
		Texture2D _NoiseTex; //For SSR
#endif
		
		float4 _GrabTexture_TexelSize;
		float4 _NoiseTex_TexelSize;
		float _NumberOfCombinedTextures;
		float _DiffuseUse, _DiffuseShift, _MediaBrightness;
		float _RoughnessIntensity, _RoughnessShift;
		float _NormalizeValue;
		float _RoughAdj;
		float _Flip;
		float4 _Ambient;
		float3 _MirrorPlace;
		float3 _MirrorScale;
		float4 _MirrorRotation;
		float4 _MainTexColor;
		float4 _MainTexColorBoost;
		float _OverrideReflection;
		float _SkyboxBrightness;
		float _AlbedoBoost;
		float _MetallicMux;
		float _MetallicShift;
		float _SmoothnessMux;
		float _SmoothnessShift;
		
		#include "/Assets/vrc-rtrti/Shaders/trace-load.cginc"

		struct Input
		{
			float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
			float3 worldRefl;
			float4 screenPos;
			INTERNAL_DATA
		};

		//https://community.khronos.org/t/quaternion-functions-for-glsl/50140/2
		float3 qtransform( in float4 q, in float3 v )
		{
			return v + 2.0*cross(cross(v, q.xyz ) + q.w*v, q.xyz);
		}
		

		// Next two https://gist.github.com/mattatz/40a91588d5fb38240403f198a938a593
		float4 q_conj(float4 q)
		{
			return float4(-q.x, -q.y, -q.z, q.w);
		}

		// https://jp.mathworks.com/help/aeroblks/quaternioninverse.html
		float4 q_inverse(float4 q)
		{
			float4 conj = q_conj(q);
			return conj / (q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
		}
		
		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _AlbedoBoost * _MainTexColor + _MainTexColorBoost;
			
			//float2 hash = chash23( float3( _Time.y * 100, IN.uv_MainTex * 1000 ) )-0.5;
			//float2 hash2 = chash23( float3( _Time.y * 100, IN.uv_MainTex * 1000 )+10. )-0.5;
			//float2 ruvx = ddx( IN.uv_MainTex ) * hash.x + ddy( IN.uv_MainTex ) * hash.y;
			float2 ruvx = 0;
			o.Normal = UnpackNormal (tex2D (_BumpMap, IN.uv_MainTex + ruvx));
			o.Normal.z+=_NormalizeValue;
			//o.Normal.xy += hash2*.01;
			o.Normal = normalize(o.Normal);
			float3 worldNormal = WorldNormalVector (IN, o.Normal);

			float3 worldViewDir = normalize(UnityWorldSpaceViewDir(IN.worldPos));
			float3 worldRefl = reflect(-worldViewDir, worldNormal);
			float4 col = 0.;

			float epsilon = 0.00;
			float3 worldEye = IN.worldPos+worldRefl*epsilon;
			float4 hitz = 1e20;
			#if defined( _ENABLERT )
			{
				hitz = CoreTrace( worldEye, worldRefl );
				o.Albedo = worldRefl*0.00001; //XXX WHYYYYY If I don't put this here, the compiler produces nonsense code.
			}
			#endif
			
			float3 debug = 0.0;
			
			#ifdef DEBUG_TRACE
			{
				float2 uvo;
				float3 hitnorm;
				col.r = (hitz.a%1000)/255;
				col.g = (hitz.a/1000)/255;
				if( hitz.y >= 0 )
				{
					GetTriDataFromPtr( worldEye, worldViewDir, hitz.xy, uvo, hitnorm );
					//col.rgb += hitnorm*.2;
				}
				o.Emission = col;
				return;
			}
			#endif

			// Test if we need to reverse-cast through a mirror.
#if 0
			if( _Flip > 0.5 ) {
			//if( 0 ) {
			//if( 1 ){
				debug = 0;
				float3 mirror_pos = _MirrorPlace;//float3( -12, 1.5, 0 );
				float3 mirror_size = qtransform( q_inverse(_MirrorRotation), _MirrorScale );
				float3 mirror_n = qtransform( q_inverse(_MirrorRotation), float3( 0, 0, -1 ) );

				float3 revray = reflect( worldRefl, mirror_n ); //float3( -worldRefl.x, worldRefl.yz );
				float3 revpos = IN.worldPos;
				
				// Make sure this ray intersects the mirror.
				float mirrort = dot( mirror_pos - IN.worldPos, mirror_n ) / dot( worldRefl, mirror_n );
				float3 mirrorp = IN.worldPos + worldRefl * mirrort;
				
				float3 relative_intersection = qtransform( q_inverse(_MirrorRotation),(mirrorp));
				if( _OverrideReflection > 0.5 || all( abs( relative_intersection.xy ) - mirror_size.zy/2 < 0 ) )
				{
					//revpos.x = -(revpos.x - mirror_pos) + mirror_pos;
					revpos = mirror_pos+reflect( revpos - mirror_pos, mirror_n );

					float4 uvoz2 = CoreTrace( revpos+revray*epsilon, revray );
					if( uvoz2.z < hitz.z )
					{
						worldEye = revpos+revray*epsilon;
						worldRefl = revray;
						hitz = uvoz2;
					}
				}
			}
#endif
			float3 hitnorm = 0;
			float3 hitworld = 1e10;
			
			if( hitz.z > 1e10 )
				col = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl )*_SkyboxBrightness;
			else
			{
				float2 uvoz = 0;
				float rz = GetTriDataFromPtr( worldEye, worldRefl, hitz, uvoz, hitnorm );

				if( uvoz.x < 1 )
				{
					col = tex2Dlod( _EmissionTex, float4( uvoz.xy, 0.0, 0.0 ) ) * _MediaBrightness;
				}
				else
				{
					hitworld = hitz.z * worldRefl + worldEye;
					float3 combtex = tex2Dlod( _CombinedRelfectionTextures, float4( uvoz.xy/float2(_NumberOfCombinedTextures, 1.0), 0, 0 ) );
//#if UNITY_LIGHT_PROBE_PROXY_VOLUME
					col.rgb = ShadeSHPerPixel ( hitnorm, 0., hitworld) * combtex * .8; //.8 is arbitrary, but slightly darker.
//#else
//					// No mechanism to get brightness.
//					col.rgb = combtex;
//#endif
			
				}
			}
			
			#ifndef SHADER_TARGET_SURFACE_ANALYSIS
				float matchz = length( _WorldSpaceCameraPos.xyz - hitworld );
				float4 ssr = 0.0;
				#if defined(_ENABLESSR)
				{
					ssr = getSSRColor( float4( worldEye, 1.0 ), worldViewDir, float4( worldRefl, 0. ), worldNormal,
						// large/small radius
						.5, .02,
						.1, // stepSize
						3, // Blur
						100, // Max steps
						0, // isLowres
						1, // Smoothness
						0.1, // Edge fade
						_GrabTexture_TexelSize.zw,
						PASS_SCREENSPACE_TEXTURE( _GrabTexture ),
						_NoiseTex,
						_NoiseTex_TexelSize.zw,
						1.0, // albedo
						1.0, // metallic
						0.0, // rtint
						1, // mask
						1, matchz ); // Alpha
					col = lerp( col.rgba, ssr.rgba, ssr.a );
				}
				#endif
			#endif
			if( length( debug )> 0.0 ) col.rgb = debug;			
			
			float rough = 1.0-tex2D(_Roughness, IN.uv_MainTex)*_RoughnessIntensity + _RoughnessShift;
			rough *= _RoughAdj;
			rough = saturate( rough );
			col = (1.-rough)*col;
			
			
			//float2 coords = IN.screenPos.xy / IN.screenPos.w*_ScreenParams.xy;
			//coords.y++;
			//float2 sgn = lerp(1,-1,coords.xy%2);
			//col = (col + sgn.y*ddx_fine( col )*.3 + sgn.y*ddy_fine( col )*.3);

			//c = 1.0;
			o.Albedo = (c.rgb-_DiffuseShift)*(_DiffuseUse);
			o.Metallic = tex2D (_Metallicity, IN.uv_MainTex) * _MetallicMux + _MetallicShift;
			o.Smoothness = tex2D (_Roughness, IN.uv_MainTex) * _SmoothnessMux + _SmoothnessShift;
			
			o.Emission = max(col,0) + c.rgb * _Ambient;
			o.Alpha = -1;
		}
		ENDCG

		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct v2f { 
				V2F_SHADOW_CASTER;
				float4 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = v.texcoord;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
