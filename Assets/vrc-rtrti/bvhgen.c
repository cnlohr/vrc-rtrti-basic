// Execute with 
//   tcc -run bvhgen.c -lm

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "unitytexturewriter.h"
#include <math.h>


#define TEXW 256
#define TEXH 2048
float asset2d[TEXH][TEXW][4];
int lineallocations[TEXH];
int totalallocations;
int trianglecount;
int bvhcount;

// Assume double-line allocation
int Allocate( int pixels, int * x, int * y )
{
	pixels = (pixels+1)/2; // Alternate top/bottom
	int i;
	for( i = 1; i < TEXH/2; i++ )
	{
		if( TEXW - lineallocations[i] > pixels )
		{
			*x = lineallocations[i];
			*y = i*2;
			lineallocations[i] += pixels;
			totalallocations += pixels;
			return 0;
		}
	}
	fprintf( stderr, "No room left in geometry map\n" );
	return -1;
}

void TWriteCopy( float * wr, float * rd, int bytes )
{
	int i;
	for( i = 0; i < bytes / sizeof(float); i++ )
	{
		wr[i] = rd[i];
	}
}

int OpenOBJ( const char * name, float ** tridata, int * tricount )
{
	//float * tridata; // x, y, z, tcx, tcy, nx, ny, nz
	//int tricount;

	FILE * f = fopen( name, "r" );
	if( !f || ferror( f ) )
	{
		fprintf( stderr, "Error: could not open model file.\n" );
		return -1;
	}
	
	float * vertices = 0;
	int vertex_count = 0;
	float * normals = 0;
	int normal_count = 0;
	float * tcoords = 0;
	int tcoord_count = 0;
	
	int c;
	int line = 0;

	while( !feof( f ) )
	{
		line++;
		int c = fgetc( f );
		if( c == 'v' )
		{
			c = fgetc( f );
			if( c == ' ' )
			{
				vertex_count++;
				vertices = realloc( vertices, vertex_count * 3 * sizeof( float ) );
				float * vend = vertices + (vertex_count - 1) * 3;
				//printf( "%p %p %d %p\n", vend, vertices, vertex_count, f );
				if( fscanf( f, "%f %f %f", vend, vend+1, vend+2 ) != 3 )
				{
					fprintf( stderr, "Error parsing vertices on line %d\n", line );
					goto fail;
				}
				
				//XXX WARNING: we invert X.
				*vend *= -1; 
			}
			else if( c == 'n' )
			{
				c = fgetc( f );
				normal_count++;
				normals = realloc( normals, normal_count * 3 * sizeof( float ) );
				float * vend = normals + (normal_count - 1) * 3;
				if( fscanf( f, "%f %f %f", vend, vend+1, vend+2 ) != 3 )
				{
					fprintf( stderr, "Error parsing normals on line %d\n", line );
					goto fail;
				}
				
			}
			else if( c == 't' )
			{
				c = fgetc( f );
				tcoord_count++;
				tcoords = realloc( tcoords, tcoord_count * 2 * sizeof( float ) );
				float * vend = tcoords + (tcoord_count - 1) * 2;
				if( fscanf( f, "%f %f", vend, vend+1 ) != 2 )
				{
					fprintf( stderr, "Error parsing tcs on line %d\n", line );
					goto fail;
				}
			}
		}
		else if( c == 'f' )
		{
			char vpt[3][128];
			c = fgetc( f );
			if( fscanf( f, "%127s %127s %127s", vpt[0], vpt[1], vpt[2] ) != 3 )
			{
				fprintf( stderr, "Error: Bad face reading on line %d\n", line );
				goto fail;
			}
			int otc = *tricount;
			(*tricount) ++;
			*tridata = realloc( *tridata, (*tricount) * 8*3 * sizeof( float ) );
			float * td = (*tridata) + otc * 8*3;
			int i;
			for( i = 0; i < 3; i++ )
			{
				int j;
				int len = strlen( vpt[i] );
				for( j = 0; j < len; j++ ) if( vpt[i][j] == '/' ) vpt[i][j] = ' ';
				int vno;
				int tno;
				int nno;
				int k = sscanf( vpt[i], "%d %d %d", &vno, &tno, &nno );
				if( k != 3 )
				{
					fprintf( stderr, "Error on line %d\n", line );
					goto fail;
				}
				vno--;
				tno--;
				nno--;
				if( vno > vertex_count || vno < 0 ) { fprintf( stderr, "Error: vertex count on line %d bad\n", line ); goto fail; }
				if( tno > tcoord_count || tno < 0 ) { fprintf( stderr, "Error: texture count on line %d bad\n", line ); goto fail; }
				if( nno > normal_count || nno < 0 ) { fprintf( stderr, "Error: normal count on line %d bad\n", line ); goto fail; }
				td[0+i*8] = vertices[vno*3+0];
				td[1+i*8] = vertices[vno*3+1];
				td[2+i*8] = vertices[vno*3+2];
				td[3+i*8] = tcoords[tno*2+0];
				td[4+i*8] = tcoords[tno*2+1];
				td[5+i*8] = normals[nno*3+0];
				td[6+i*8] = normals[nno*3+1];
				td[7+i*8] = normals[nno*3+2];
			}
		}
		while( ( c = fgetc( f ) ) != '\n' ) if( c == EOF ) break;
	}
	goto finish;
fail:
	*tricount = -1;
finish:
	free( vertices );
	free( normals );
	free( tcoords );
	return *tricount;
}

#define MAX_BVPER 4
#define MAX_TRIPER 2

struct BVHPair
{
	struct BVHPair * a;
	struct BVHPair * b;
	struct BVHPair * parent;
	float minxmaxh[8];
	int triangle_number; /// If -1 is a inner node.
	int x, y; // Start
	int w, h; // Size (right now 2 for bv, 8 for triangle)
	
	int trix, triy;
	int height;
};


void cross3d( float * out, const float * a, const float * b )
{
	out[0] = a[1]*b[2] - a[2]*b[1];
	out[1] = a[2]*b[0] - a[0]*b[2];
	out[2] = a[0]*b[1] - a[1]*b[0];
}

float dist3d( const float * a, const float * b )
{
	float del[3];
	del[0] = a[0] - b[0];
	del[0] *= del[0];
	del[1] = a[1] - b[1];
	del[1] *= del[1];
	del[2] = a[2] - b[2];
	del[2] *= del[2];
	return sqrt( del[0] + del[1] + del[2] );
}

float mag3d( const float * a )
{
	return sqrt( a[0] * a[0] + a[1] * a[1] + a[2] * a[2] );
}

void mul3d( float * val, float mag)
{
	val[0] = val[0] * mag;
	val[1] = val[1] * mag;
	val[2] = val[2] * mag;
}

void GetTreeExtents( struct BVHPair * pairs, const float * tridata, float * mins, float * maxs )
{
	if( pairs->a ) GetTreeExtents( pairs->a, tridata, mins, maxs );
	if( pairs->b ) GetTreeExtents( pairs->b, tridata, mins, maxs );
	int t = pairs->triangle_number;
	if( t >= 0 )
	{
		const float * tv = tridata + t*24;	
		if( tv[0] > maxs[0] ) maxs[0] = tv[0]; if( tv[0] < mins[0] ) mins[0] = tv[0];
		if( tv[1] > maxs[1] ) maxs[1] = tv[1]; if( tv[1] < mins[1] ) mins[1] = tv[1];
		if( tv[2] > maxs[2] ) maxs[2] = tv[2]; if( tv[2] < mins[2] ) mins[2] = tv[2];

		if( tv[0+8] > maxs[0] ) maxs[0] = tv[0+8]; if( tv[0+8] < mins[0] ) mins[0] = tv[0+8];
		if( tv[1+8] > maxs[1] ) maxs[1] = tv[1+8]; if( tv[1+8] < mins[1] ) mins[1] = tv[1+8];
		if( tv[2+8] > maxs[2] ) maxs[2] = tv[2+8]; if( tv[2+8] < mins[2] ) mins[2] = tv[2+8];

		if( tv[0+16] > maxs[0] ) maxs[0] = tv[0+16]; if( tv[0+16] < mins[0] ) mins[0] = tv[0+16];
		if( tv[1+16] > maxs[1] ) maxs[1] = tv[1+16]; if( tv[1+16] < mins[1] ) mins[1] = tv[1+16];
		if( tv[2+16] > maxs[2] ) maxs[2] = tv[2+16]; if( tv[2+16] < mins[2] ) mins[2] = tv[2+16];
	}
}

float GetTreeMaxr( struct BVHPair * pairs, const float * tridata, const float * point, float maxr )
{
	float r;
	if( pairs->a )
	{
		r = GetTreeMaxr( pairs->a, tridata, point, maxr );
		if( r > maxr ) maxr = r;
	}
	if( pairs->b )
	{
		r = GetTreeMaxr( pairs->b, tridata, point, maxr );
		if( r > maxr ) maxr = r;
	}
	int t = pairs->triangle_number;
	if( t >= 0 )
	{
		const float * tv = tridata + t*24;	
		float d;
		d = tv[0]-point[0]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
		d = tv[1]-point[1]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
		d = tv[2]-point[2]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;

		d = tv[0+8]-point[0]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
		d = tv[1+8]-point[1]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
		d = tv[2+8]-point[2]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;

		d = tv[0+16]-point[0]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
		d = tv[1+16]-point[1]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
		d = tv[2+16]-point[2]; if( d < 0 ) d = -d; if( d > maxr ) maxr = d;
	}
	return maxr;
}

void GetMinXMaxHForTree( struct BVHPair * pairs, float * tridata, float * minxmaxh )
{
	minxmaxh[0] = 1e20;
	minxmaxh[1] = 1e20;
	minxmaxh[2] = 1e20;
	minxmaxh[3] = 0;
	minxmaxh[4] =-1e20;
	minxmaxh[5] =-1e20;
	minxmaxh[6] =-1e20;
	minxmaxh[7] = 0;

	GetTreeExtents( pairs, tridata, minxmaxh, minxmaxh+4 );

	int ahi = pairs->a?pairs->a->height:0;
	int bhi = pairs->b?pairs->b->height:0;
	
	// Not sure why - the math breaks down if any one axis is 0.
	if( (minxmaxh[4] - minxmaxh[0]) < 0.0001 ) minxmaxh[0] -= 0.0001;
	if( (minxmaxh[5] - minxmaxh[1]) < 0.0001 ) minxmaxh[1] -= 0.0001;
	if( (minxmaxh[6] - minxmaxh[2]) < 0.0001 ) minxmaxh[2] -= 0.0001;
	minxmaxh[7] = (minxmaxh[4] - minxmaxh[0]) + (minxmaxh[5] - minxmaxh[1]) + (minxmaxh[6] - minxmaxh[2]) + (ahi+bhi)*.01;
}


struct BVHPair * BuildBVH( struct BVHPair * pairs, float * tridata, int tricount )
{
	memset( pairs, 0, sizeof( pairs ) );
	int nrpairs;
	float * trimetadata = malloc( tricount * 4 * sizeof( float ) );
	int i;
	for( i = 0; i < tricount; i++ )
	{
		pairs[i].triangle_number = i;
		pairs[i].height = 0;
		GetMinXMaxHForTree( pairs + i, tridata, pairs[i].minxmaxh );
		printf( "%d  %f %f %f  %f %f %f  %f\n", i, pairs[i].minxmaxh[0], pairs[i].minxmaxh[1], pairs[i].minxmaxh[2], pairs[i].minxmaxh[4], pairs[i].minxmaxh[5], pairs[i].minxmaxh[6], pairs[i].minxmaxh[7]  );

		
		// Just FYI for this hitmiss[0] / 1 will be negative
		float * this_tri = tridata + pairs[i].triangle_number * 24;
		float tt[24];
		memcpy( tt, this_tri, sizeof( tt ) );
		int x, y;
		Allocate( 8, &x, &y );
		pairs[i].trix = x;
		pairs[i].triy = y;
		
		// Make v1, v2 of tri be relative to v0.
		tt[8]  -= tt[0];
		tt[9]  -= tt[1];
		tt[10] -= tt[2];
		tt[16] -= tt[0];
		tt[17] -= tt[1];
		tt[18] -= tt[2];

		TWriteCopy( asset2d[y+0][x+0], tt+0, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+0], tt+4, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+0][x+1], tt+8, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+1], tt+12, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+0][x+2], tt+16, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+2], tt+20, sizeof( float ) * 4 );
	}

	printf( "------------------------------------------\n");
	nrpairs = i;
	

	// Now, pairs from 0..tricount are leaf (Triangle) nodes on up.
	// Building a BVH this way isn't perfectly optimal but for a binary BVH, it's really good.
	int any_left = 0;
	do
	{
		any_left = 0;
		int besti = -1, bestj = -1;
		float smallestq = 1e20;
		int i, j, objct = 0;;
		for( j = 0; j < nrpairs; j++ )
		{
			struct BVHPair * jp = pairs+j;
			if( jp->parent ) continue; // Already inside a tree.
			objct++;
			if( jp->minxmaxh[7] > smallestq ) continue;  //Don't check objects that are plain too big.
			for( i = j+1; i < nrpairs; i++ )
			{
				if( i == j ) continue;
				struct BVHPair * ip = pairs+i;
				if( ip->parent ) continue; // Already inside a tree.
				if( ip->minxmaxh[7] > smallestq ) continue;  //Don't check objects that are plain too big.
				any_left = 1;
				
				// Compute BB from these two objects, and find heuristic size.
				float newmax[3] = {
					( ip->minxmaxh[4] > jp->minxmaxh[4] ) ? ip->minxmaxh[4] : jp->minxmaxh[4],
					( ip->minxmaxh[5] > jp->minxmaxh[5] ) ? ip->minxmaxh[5] : jp->minxmaxh[5], 
					( ip->minxmaxh[6] > jp->minxmaxh[6] ) ? ip->minxmaxh[6] : jp->minxmaxh[6] };
				float newmin[3] = {
					( ip->minxmaxh[0] < jp->minxmaxh[0] ) ? ip->minxmaxh[0] : jp->minxmaxh[0],
					( ip->minxmaxh[1] < jp->minxmaxh[1] ) ? ip->minxmaxh[1] : jp->minxmaxh[1],
					( ip->minxmaxh[2] < jp->minxmaxh[2] ) ? ip->minxmaxh[2] : jp->minxmaxh[2] };
				float q = ( newmax[0] - newmin[0] ) + (newmax[1] - newmin[1]) + (newmax[2] - newmin[2]) + (ip->height+jp->height)*.01;

				if( q < smallestq )
				{
					smallestq = q;
					besti = i;
					bestj = j;
				}
			}
		}
		//[%f %f %f] [%f %f %f]
		//if( smallestq < pairs[bestj].minxmaxh[7] ) { fprintf( stderr, "ERROR FAULT: %f %f \n", smallestq, pairs[bestj].minxmaxh[7] ); }//, newmax[0], newmax[1], newmax[2], newmin[0], newmin[1], newmin[2] ); }

		if (!any_left) break;
		if ( besti < 0 || bestj < 0 )
		{
			fprintf( stderr, "Error with tree assembly\n" );
			return 0;
		}
		
		// Pair them up.
		struct BVHPair * jp = pairs+bestj;
		struct BVHPair * ip = pairs+besti;
		//printf( "%d %p %d %p %d\n", besti, ip->parent, bestj, jp->parent, nrpairs );
		struct BVHPair * parent = pairs + nrpairs;
		parent->a = jp;
		parent->b = ip;
		parent->triangle_number = -1;
		parent->height = ((jp->height>ip->height)?jp->height:ip->height)+1;
		// Greedily find new optimal sphere.
		GetMinXMaxHForTree( parent, tridata, parent->minxmaxh );
		printf( "%d/%d  %f %f %f  %f %f %f  %f\n", i, objct, pairs[i].minxmaxh[0], pairs[i].minxmaxh[1], pairs[i].minxmaxh[2], pairs[i].minxmaxh[4], pairs[i].minxmaxh[5], pairs[i].minxmaxh[6], pairs[i].minxmaxh[7]  );

/*
		// Tricky - joining two spheres. 
		float * xyzr = parent->xyzr;
		float vecji[3] = { jp->xyzr[0] - ip->xyzr[0], jp->xyzr[1] - ip->xyzr[1], jp->xyzr[2] - ip->xyzr[2] };
		float lenji = dist3d( jp->xyzr, ip->xyzr );
		if( lenji > 0.001 )
			mul3d( vecji, 1.0/lenji );
		else
			mul3d( vecji, 0.0 );
		// edgej / lenji / edgei
		// Special case: If one bv completely contains another.
		//  i.e. edgej = 10, lenji = 1, edgei = 1
		float edgej = jp->xyzr[3];
		float edgei = ip->xyzr[3];
		if( edgej > lenji + edgei )
		{
			memcpy( xyzr, jp->xyzr, sizeof( jp->xyzr ) );
			//printf( "J %d (%f+%f+%f) %d %d <%f %f %f %f - %f %f %f %f>\n", nrpairs, edgej, lenji, edgei, besti, bestj, ip->xyzr[0], ip->xyzr[1], ip->xyzr[2], ip->xyzr[3], jp->xyzr[0], jp->xyzr[1], jp->xyzr[2], jp->xyzr[3] );
		}
		else if( edgej + lenji < edgei )
		{
			memcpy( xyzr, ip->xyzr, sizeof( ip->xyzr ) );
			//printf( "I %d (%f+%f+%f) %d %d <%f %f %f %f - %f %f %f %f>\n", nrpairs, edgej, lenji, edgei, besti, bestj, ip->xyzr[0], ip->xyzr[1], ip->xyzr[2], ip->xyzr[3], jp->xyzr[0], jp->xyzr[1], jp->xyzr[2], jp->xyzr[3] );
		}
		else
		{
			// The new center is between the two.
			float r1 = edgei;
			float r2 = edgej;
			float * c1 = ip->xyzr;
			float * c2 = jp->xyzr;
			float clen = lenji;
			float R = ( r1 + r2 + clen )/2;
			if( clen < 0.00001 )
			{
				// You get this if you have duplicate geometry (or opposite facing geometry)
				xyzr[0] = c1[0];
				xyzr[1] = c1[1];
				xyzr[2] = c1[2];
			}
			else
			{
				xyzr[0] = c1[0] + ( c2[0] - c1[0] ) * (R - r1) / clen;
				xyzr[1] = c1[1] + ( c2[1] - c1[1] ) * (R - r1) / clen;
				xyzr[2] = c1[2] + ( c2[2] - c1[2] ) * (R - r1) / clen;
			}
			xyzr[3] = R;
			printf( "Join %d\n", nrpairs );
#if 0
			float edgesize = (edgej + lenji + edgei)/2;
			float center = edgesize - edgei;
			center /= lenji;
			mul3d( vecji, center );
			float * ix = ip->xyzr;
			//add3d( xyzr, vecji, ix );
			xyzr[0] = vecji[0] + ix[0];
			xyzr[1] = vecji[1] + ix[1];
			xyzr[2] = vecji[2] + ix[2];
			xyzr[3] = edgesize*10;
			printf( "B %d %f %f (%f+%f+%f) %d %d <%f %f %f %f - %f %f %f %f> = %f %f %f %f\n", nrpairs, center, edgesize, edgej, lenji, edgei, besti, bestj, ip->xyzr[0], ip->xyzr[1], ip->xyzr[2], ip->xyzr[3], jp->xyzr[0], jp->xyzr[1], jp->xyzr[2], jp->xyzr[3],
				xyzr[0], xyzr[1], xyzr[2], xyzr[3] );
#endif
		}
		*/
		
		jp->parent = parent;
		ip->parent = parent;
		nrpairs++;
	} while( 1 );
	printf( "Done\n" );
	return pairs + nrpairs - 1;
}


int AllocateBVH( struct BVHPair * tt )
{
	tt->h = 2;
	tt->w = (tt->triangle_number<0)?4:6;

	if( Allocate( tt->w, &tt->x, &tt->y ) < 0 )
		return -1;

	trianglecount += (tt->triangle_number<0)?0:1;
	bvhcount ++;
	
	if( tt->a ) 
		if( AllocateBVH( tt->a ) < 0 )
			return -1;
	if( tt->b )
		if( AllocateBVH( tt->b ) < 0 )
			return -1;
	return 0;
}

// Get the "next" node if this node is false.
struct BVHPair * FindFallBVH( struct BVHPair * tt )
{
	// If root of tree, we are freeeee
	if( !tt->parent ) return 0;
	
	if( tt->parent->b != tt )
		return tt->parent->b;
	
	return FindFallBVH( tt->parent );
}



int WriteInBVH( struct BVHPair * tt, float * triangles )
{
	// BVH
	if( tt->a )
		WriteInBVH( tt->a, triangles );
	if( tt->b )
		WriteInBVH( tt->b, triangles );

	// Fill our "hit" in to be 
	int x = tt->x;
	int y = tt->y;
	
	int j;
	float * hitmiss = asset2d[y+1][x+0];
	if( !tt->a )
	{
		//XXXX TOOD If we have a "HIT" on a leaf node, what does that mean?
		hitmiss[0] = -1;
		hitmiss[1] = -1;
	}
	else
	{
		hitmiss[0] = tt->a->x;
		hitmiss[1] = tt->a->y;
	}

	struct BVHPair * next = FindFallBVH( tt );
	if( next )
	{
		hitmiss[2] = next->x;
		hitmiss[3] = next->y;
	}
	else
	{
		hitmiss[2] = -1;
		hitmiss[3] = -1;
	}
	
	if( hitmiss[0] == -1 )
	{
		hitmiss[0] = hitmiss[2];
		hitmiss[1] = hitmiss[3];
		tt->minxmaxh[7] = 1;
	}
	else
	{
		tt->minxmaxh[7] = 0;
	}

	//memcpy( asset2d[y][x], tt->centerextents, sizeof( float ) * 8 );
	//asset2d[y][x][3] = asset2d[y][x][3] * asset2d[y][x][3];// Tricky: We do r^2 because that makes the math work out better in the shader.

	// Calculate radius
	
	float dx = (tt->minxmaxh[4] - tt->minxmaxh[0])/2;
	float dy = (tt->minxmaxh[5] - tt->minxmaxh[1])/2;
	float dz = (tt->minxmaxh[6] - tt->minxmaxh[2])/2;
	tt->minxmaxh[3] = sqrt( dx*dx + dy*dy + dz*dz );

	TWriteCopy( asset2d[y+0][x+0], tt->minxmaxh, sizeof( float ) * 8 );


	if( tt->triangle_number >= 0 )
	{
		// Just FYI for this hitmiss[0] / 1 will be negative
		float * this_tri = triangles + tt->triangle_number * 24;
		float ttcopy[24];
		memcpy( ttcopy, this_tri, sizeof(float)*24 );
		
		ttcopy[3] = tt->trix;
		ttcopy[8] -= this_tri[0];
		ttcopy[9] -= this_tri[1];
		ttcopy[10] -= this_tri[2];
		ttcopy[11] = tt->triy;
		ttcopy[16] -= this_tri[0];
		ttcopy[17] -= this_tri[1];
		ttcopy[18] -= this_tri[2];
		TWriteCopy( asset2d[y+1][x+1], ttcopy+0, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+0][x+2], ttcopy+8, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+2], ttcopy+16, sizeof( float ) * 4 );
/*
		
		// Make v1, v2 of tri be relative to v0.
		this_tri[8] -= this_tri[0];
		this_tri[9] -= this_tri[1];
		this_tri[10] -= this_tri[2];
		this_tri[16] -= this_tri[0];
		this_tri[17] -= this_tri[1];
		this_tri[18] -= this_tri[2];

		TWriteCopy( asset2d[y+0][x+2], this_tri+0, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+2], this_tri+4, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+0][x+3], this_tri+8, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+3], this_tri+12, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+0][x+4], this_tri+16, sizeof( float ) * 4 );
		TWriteCopy( asset2d[y+1][x+4], this_tri+20, sizeof( float ) * 4 );
*/

		// Compute the normal to the surface of this triangle.
	//	float dA[3] = { this_tri[8], this_tri[9], this_tri[10] };
	//	float dB[3] = { this_tri[16], this_tri[17], this_tri[18] };
	//	float norm[3];
	//	cross3d( norm, dA, dB );
	//	mul3d( norm, 1.0/mag3d( norm ) );
	//	TWriteCopy( asset2d[y+1][x+1], norm, sizeof(float)*3 );
	}

	return 0;
}

int CountTrianglesInTree( struct BVHPair * tt )
{
	struct BVHPair * a = tt->a;
	struct BVHPair * b = tt->b;
	return (tt->triangle_number>=0) + (a?CountTrianglesInTree(a):0) + (b?CountTrianglesInTree(b):0);
}

void ReorganizeTreeOrder( struct BVHPair * tt, int dir )
{
	if( tt->a ) ReorganizeTreeOrder( tt->a, dir );
	if( tt->b ) ReorganizeTreeOrder( tt->b, dir );
	
	if( tt->a && tt->b )
	{
		int axis = dir / 2;
		float cna = (tt->a->minxmaxh[axis]+tt->a->minxmaxh[axis+4])/2;
		float cnb = (tt->b->minxmaxh[axis]+tt->b->minxmaxh[axis+4])/2;		
		if( dir & 1 )
		{
			if( cna > cnb )
			{
				struct BVHPair * temp = tt->a;
				tt->a = tt->b;
				tt->b = temp;
			}
			else
			{
			}
		}
		else
		{
			if( cna > cnb )
			{
			}
			else
			{
				struct BVHPair * temp = tt->a;
				tt->a = tt->b;
				tt->b = temp;
			}
		}
		
	}
}


int main( int argc, char ** argv )
{
	if( argc != 3 )
	{
		fprintf( stderr, "Error: Usage: bvhgen [low quality .obj input file] [geometry image .asset output file]\n" );
		return -6;
	}
	
	float * tridata = 0;
	int tricount = 0;
	if( OpenOBJ( argv[1], &tridata, &tricount ) <= 0 )
	{
		fprintf( stderr, "Error: couldn't open OBJ file\n" );
		return -1;
	}
	
	printf( "TRICOUNT: %d\n", tricount );
	struct BVHPair * allpairs = calloc( sizeof( struct BVHPair ), tricount*2+3 );
	struct BVHPair * root = BuildBVH( allpairs, tridata, tricount );

	int axis;
	for( axis = 0; axis < 6; axis++ )
	{
		ReorganizeTreeOrder( root, axis );

		if( AllocateBVH( root ) < 0 )
			return -1;	

		WriteInBVH( root, tridata );
		
		asset2d[0][axis][0] = root->x;
		asset2d[0][axis][1] = root->y;
		printf( "WRITING %d %d\n", root->x, root->y );
	}
	
	// Flip Unity Asset
	if( 0 )
	{
		int y;
		for( y = 0; y < TEXH/2; y++ )
		{
			uint8_t linedata[TEXW*16];
			memcpy( linedata, asset2d[y], sizeof( asset2d[0] ) );
			memcpy( asset2d[y], asset2d[TEXH-1-y], sizeof( linedata) ) ;
			memcpy( asset2d[TEXH-1-y], linedata, sizeof( linedata) ) ;
		}
	}

	WriteUnityImageAsset( argv[2], asset2d, sizeof(asset2d), TEXW, TEXH, 0, UTE_RGBA_FLOAT );

	printf( "Usage: %d / %d (%3.2f%%)\n", totalallocations, TEXW*TEXH, ((float)totalallocations)/(TEXW*TEXH)*100. );
	printf( "Triangles: %d\n", CountTrianglesInTree( root ) );
	printf( "BVH Count: %d\n", bvhcount );
}
