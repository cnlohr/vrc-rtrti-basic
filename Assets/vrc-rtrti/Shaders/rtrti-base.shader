Shader "Unlit/rtrti-base"
{
	Properties
	{
		_EmissionTex ("Emission Texture", 2D) = "white" {}
		_MainTex("Main Texture", 2D) = "white" {}
		_Roughness("Roughness", 2D) = "white" {}
		_Metallicity("Metallicity", 2D) = "white" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		_GeoTex ("Geometry", 2D) = "black" {}
		_DiffuseUse( "Diffuse Use", float ) = .1
		_MediaBrightness( "Media Brightness", float ) = 1.2
		_UVScale(  "UV Scale", Vector ) = ( 2, 2, 0, 0 )
		_RoughnessIntensity( "Roughness Intensity", float ) = 3.0
		_NormalizeValue("Normalize Value", float) = 0.0
		_Flip("Flip Mirror Enable", float ) =0.0
		_MirrorPlace("Mirror Place", Vector ) = ( 0, 0, 0, 0)
		_MirrorScale("Mirror Enable", Vector ) = ( 0, 0, 0, 0)
		_MirrorRotation("Mirror Rotation", Vector ) = ( 0, 0, 0, 0)
		_OverrideReflection( "Override Reflection", float)=0.0
		_RoughAdj("Roughness Adjust", float) = 0.3
	}
	SubShader
	{
	
	
	
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			#include "/Assets/vrc-rtrti/Shaders/trace.cginc"
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 worldPos : TEXCOORD2;
				
				
				float3 tspace0 : TEXCOORD3; // tangent.x, bitangent.x, normal.x
				float3 tspace1 : TEXCOORD4; // tangent.y, bitangent.y, normal.y
				float3 tspace2 : TEXCOORD5; // tangent.z, bitangent.z, normal.z
			};

			sampler2D _BumpMap, _MainTex, _Roughness, _Metallicity;
			float _DiffuseUse, _MediaBrightness;
			float4 _UVScale;
			float _RoughnessIntensity;
			float _NormalizeValue;
			float _RoughAdj;
			float _Flip;


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

			float3 _MirrorPlace;
			float3 _MirrorScale;
			float4 _MirrorRotation;
			float _OverrideReflection;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv * _UVScale;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                half3 wNormal = UnityObjectToWorldNormal(v.normal);
				
				float3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
				// compute bitangent from cross product of normal and tangent
				float3 tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				float3 wBitangent = cross(wNormal, wTangent) * tangentSign;
				// output the tangent space matrix
				o.tspace0 = float3(wTangent.x, wBitangent.x, wNormal.x);
				o.tspace1 = float3(wTangent.y, wBitangent.y, wNormal.y);
				o.tspace2 = float3(wTangent.z, wBitangent.z, wNormal.z);
				
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float3 tnormal = UnpackNormal(tex2D(_BumpMap, i.uv));
				tnormal.z+=_NormalizeValue;
				tnormal = normalize(tnormal);
	            half3 worldNormal;
                worldNormal.x = dot(i.tspace0, tnormal);
                worldNormal.y = dot(i.tspace1, tnormal);
                worldNormal.z = dot(i.tspace2, tnormal);

				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				float3 worldRefl = reflect(-worldViewDir, worldNormal);
				

				float4 col = 1;
				float3 hitnorm;
				float4 uvozi = CoreTrace( i.worldPos, worldRefl );
				if( uvozi.x > 1.0 ) col = 0.0;

				float3 debug = 0.0;
#if 0
				// Test if we need to reverse-cast through a mirror.
				if( _Flip > 0.5 )
				{
					float3 mirror_pos = _MirrorPlace;//float3( -12, 1.5, 0 );
					float3 mirror_size = qtransform( q_inverse(_MirrorRotation), _MirrorScale );
					float3 mirror_n = qtransform( q_inverse(_MirrorRotation), float3( 0, 0, -1 ) );

					float3 revray = reflect( worldRefl, mirror_n ); //float3( -worldRefl.x, worldRefl.yz );
					float3 revpos = i.worldPos;
					
					// Make sure this ray intersects the mirror.
					float mirrort = dot( mirror_pos - i.worldPos, mirror_n ) / dot( worldRefl, mirror_n );
					float3 mirrorp = i.worldPos + worldRefl * mirrort;
					
					float3 relative_intersection = qtransform( q_inverse(_MirrorRotation),(mirrorp));
					if( _OverrideReflection > 0.5 || all( abs( relative_intersection.xy ) - mirror_size.zy/2 < 0 ) )
					{
						debug = relative_intersection;
						//revpos.x = -(revpos.x - mirror_pos) + mirror_pos;
						revpos = mirror_pos+reflect( revpos - mirror_pos, mirror_n );

						float z2;
						float4 c2 = CoreTrace( revpos, revray, z2, uvo ) * _MediaBrightness;
						if( uvo.x > 1.0 ) col = 0.0;
						if( z2 < z )
						{
							col = c2;
							z = z2;
						}
					}
				}
#endif

				if( uvozi.z > 1e10 )
					col = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldNormal )*.5;
				

				float rough = 1.0-tex2D(_Roughness, i.uv)*_RoughnessIntensity;
				rough *= _RoughAdj;
				col = (1.-rough)*col + tex2D(_MainTex, i.uv)*_DiffuseUse*rough;
				
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
