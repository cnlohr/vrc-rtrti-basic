Shader "Unlit/rtrti-test"
{
	Properties
	{
		_GeoTex ("Geometry", 2D) = "black" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		cull off
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog


			#define DEBUG_TRACE
			
			#include "UnityCG.cginc"
			#include "/Assets/vrc-rtrti/Shaders/trace.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 worldView : TEXCOORD2;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;				
				o.worldView = worldPos - _WorldSpaceCameraPos.xyz;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			fixed4 frag (v2f inval) : SV_Target
			{
				float3 dir = normalize( inval.worldView );
				float3 eye = _WorldSpaceCameraPos.xyz;

				float4 ptrzct = CoreTrace( eye, dir );
				float3 hitnorm = 0;
				float4 col = 0;
				float2 uvo;

				col.r = (ptrzct.a%1000)/255;
				col.g = (ptrzct.a/1000)/255;
				if( ptrzct.y >= 0 )
				{
					GetTriDataFromPtr( eye, dir, ptrzct.xy, uvo, hitnorm );
					col.rgb += hitnorm*.2;
				}
				
				UNITY_APPLY_FOG(i.fogCoord, col);
				return float4( col.xyz, 1.0 );
			}
			ENDCG
		}
	}
}
