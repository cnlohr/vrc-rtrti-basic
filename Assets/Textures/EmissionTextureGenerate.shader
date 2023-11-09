Shader "CustomRenderTexture/EmissionTextureGenerate"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_Tex("InputTex", 2D) = "white" {}
		[ToggleUI] _IsAVProInput("Is AVPro", float) = 0
		[Toggle(_USE_AUDIOLINK_FOR_PANES)] _USE_AUDIOLINK_FOR_PANES("Use AudioLink For Panes", float) = 1
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
					if( uv.y < 0.1 )
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
				return _Color * float4( col, 1.0 );
			}
			ENDCG
		}
	}
}