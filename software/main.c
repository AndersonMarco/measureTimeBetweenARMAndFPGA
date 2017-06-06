#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <sys/mman.h>
#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "socal/alt_gpio.h"
#include "hps_0.h"
//#include "led.h"
//#include "seg7.h"
#include <stdbool.h>
#include <pthread.h>

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )


//setting for the HPS2FPGA AXI Bridge
#define ALT_AXI_FPGASLVS_OFST (0xC0000000) // axi_master
#define HW_FPGA_AXI_SPAN (0x40000000) // Bridge span 1GB
#define HW_FPGA_AXI_MASK ( HW_FPGA_AXI_SPAN - 1 )

volatile unsigned long *h2p_lw_output_addr[6];
volatile unsigned long *h2p_lw_input_addr[6];
void *process(void *argument){
    
    int id = *( ( int* )argument );
    int stage=0;
    printf("%d\n",id);
    while(1){
        if(stage==0){
              
            alt_write_word(h2p_lw_output_addr[id], UINT32_C(1) );
            stage=1;
        }
        else if(stage==1){
            if( (*(uint32_t *)h2p_lw_input_addr[id])==UINT32_C(0x00020000)){
                alt_write_word(h2p_lw_output_addr[id], UINT32_C(0x200) | UINT32_C(1) );          
                stage=2;
            }
        }
        else if(stage==2){
            uint32_t temp=(*(uint32_t *)h2p_lw_input_addr[id]);
            if(temp>>16==3){
                printf("%d:%x\n",id,temp&0xffff);
                //stage=0;
            }
        }               
    }
    return NULL;  
}

int main(int argc, char **argv)
{
	pthread_t threads[16];
    int ids[16];
	int ret;
	void *virtual_base;
    void *axi_virtual_base;
	int fd;
    int i;
	// map the address space for the LED registers into user space so we can interact with them.
	// we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span
	if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
		printf( "ERROR: could not open \"/dev/mem\"...\n" );
		return( 1 );

	}
	virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );	
	if( virtual_base == MAP_FAILED ) {
		printf( "ERROR: mmap() failed...\n" );
		close( fd );
		return(1);
	}
    axi_virtual_base = mmap( NULL, HW_FPGA_AXI_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd,ALT_AXI_FPGASLVS_OFST );
    if( axi_virtual_base == MAP_FAILED ) {
		printf( "ERROR: axi mmap() failed...\n" );
		close( fd );
		return( 1 );
    }
    
    for(i=0;i<6;i++){
        ids[i]=i;
        h2p_lw_output_addr[i]=NULL;
        h2p_lw_input_addr[i]=virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + (PIO_INPUT_BASE+i*16) ) & ( unsigned long)( HW_REGS_MASK ) );

        h2p_lw_output_addr[i]=virtual_base + ( ( unsigned long )( ALT_LWFPGASLVS_OFST + (PIO_OUTPUT_BASE+i*16) ) & ( unsigned long)(  HW_REGS_MASK ) );
        printf("%x\n",(PIO_INPUT_BASE+i*16));
    }
    
    for(i=0;i<6;i++){
        pthread_create( &threads[i], NULL, process, &ids[i] );
    }
    for(i=0;i<6;i++){
        pthread_join( threads[i], NULL );
    }
    
    int stage=0;
    int id=0;
  

    
	close( fd );
	return 0;
}
