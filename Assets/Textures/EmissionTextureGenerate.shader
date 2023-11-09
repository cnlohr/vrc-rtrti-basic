Shader "CustomRenderTexture/EmissionTextureGenerate"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_Tex("InputTex", 2D) = "white" {}
		[ToggleUI] _IsAVProInput("Is AVPro", float) = 0
		[Toggle(_USE_AUDIOLINK_FOR_PANES)] _USE_AUDIOLINK_FOR_PANES("Use AudioLink For Panes", float) = 1
		[Toggle(_REDUCED_INTENSITY)] _REDUCED_INTENSITY("Reduced Intensity", float) = 1
	 }

	 SubShader
	 {
		Lighting Off
		Blend One Zero

		
		Pass
		{
			CGPROGRAM
			#include "UnityCustomRenderTexture.cginc"
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#pragma target 3.0
			
			#pragma multi_compile_local _  _USE_AUDIOLINK_FOR_PANES
			#pragma multi_compile_local _  _REDUCED_INTENSITY

			float _IsAVProInput;
			float4	  _Color;
			sampler2D   _Tex;

			#include "/Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc" 

			float4 frag(v2f_customrendertexture IN) : COLOR
			{
				float2 uv = IN.localTexcoord.xy;
				float3 col;
				
				if( uv.y > 1.0 - 1090.0 / 1280.0 ) // Not 1080 to add a little edge to prevent ugly bleeding.
				{
					if( _IsAVProInput )
					{
						uv.y *= (1090.0/1280.0);
						uv.y = 1.0 - uv.y;
						col = tex2D(_Tex, uv);
						col = GammaToLinearSpace( col );
						//col.rgb = pow(col.rgb,1.4);
					}
					else
					{
						col = tex2D(_Tex, uv);
					}
				}
				else
				{
					if( uv.y < 0.04 )
					{
						col = AudioLinkData( ALPASS_CCSTRIP + uint2( uv.x * 128, 0.0 ) );
					}
					else
					if( uv.y < 0.12 )
					{
					#ifdef _USE_AUDIOLINK_FOR_PANES
						col = AudioLinkData( ALPASS_THEME_COLOR0 + uint2( uv.x * 8, 0.0 ) );
					#else
						uv.x = float( floor( uv.x * 4 ) ) / 4;
						col = tex2D(_Tex, uv - float2( 0.0, 0.5 ));
					#endif
					}
					else
					{
						col = 0.0;
					}
				}
				
				float3 colorOO = _Color * float3( col );
				#ifdef _REDUCED_INTENSITY

					// Hash Without Sine // Copyright (c)2014 David Hoskins. // See https://www.shadertoy.com/view/4djSRW
					float3 p3 = float3( frac( _Time.y ) * 100.0, IN.localTexcoord.xy * 1000.0 );
					p3  = frac(p3 * .1031);
					p3 += dot(p3, p3.zyx + 31.32);
					float3 hasho = frac((p3.x + p3.y) * p3.z);
					hasho = hasho * hasho * hasho;

				colorOO = colorOO * 0.03 + tex2D( _SelfTexture2D, IN.localTexcoord.xy ) * 0.97 - 0.005 * hasho;
				#endif
				
				
				return float4( colorOO, 1.0 );
			}
			ENDCG
		}
	}
}