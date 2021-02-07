
enum ResourceBarrierType
{
    ResourceBarrierType_alias
};
 
struct ResourceState
{
    D12Resource* resource;
    D3D12_RESOURCE_STATES before_state;
    D3D12_RESOURCE_STATES after_state;
};

struct ResourceTableEntry
{
    D12Resource* resource;
    f2 sub_resource_range;//range in the table of sub_resources.
};

enum SubResourceType
{
    SubResourceType_buffer,
    SubResourceType_1dtex,
    SubResourceType_2dtex,
    SubResourceType_3dtex
};


struct SubResourceTableEntry
{
    ResourceTableEntry* resource;
    SubResourceType type;
};

struct ResourceBarriers
{
    D3D12_RESOURCE_TRANSITION_BARRIER* barrier;
    D12ResourceStateEntry* resource;
    D3D12_RESOURCE_STATES before_state;
    D3D12_RESOURCE_STATES after_state;
    D12CommandListEntry* cl;
};

struct ResourceTracker
{
    AnyCache resource_table;
    AnyCache sub_resource_table;//Is a range of resources lined to resources
    AnyCache pending_resource_barriers;
};

struct ResourceTableEntryKey
{
    uint64_t resource;//Cant have duplicates in the table
};

struct SubResourceTableEntryKey
{
    uint64_t resource;//Cant have duplicates in the table
    SubResourceType type;
};

struct ResourceBarriersKey
{
    uint64_t resource;
    SubResourceType type;
};

struct PerThreadResourceState
{
    FMJStretchBuffer resource_state_vectors;//one per thread we are writing command lists too.
};

struct D12RootSignature
{
    ID3D12RootSignature* state;
    D3D12_ROOT_SIGNATURE_DESC desc;
};

#define MAX_CPU_WORKER_THREADS 10
namespace D12ResourceState 
{
    enum
    {
        GenerateMipsCB,
        SrcMip,
        OutMip,
        NumRootParameters
    };
    
    ResourceTracker tracker;
    PerThreadResourceState per_thread_resource_state;
    
    D12RootSignature root_sig;
    uint32_t desc_table_bitmask;
    uint32_t sampler_table_bitmask;
    uint32_t num_of_desc_per_table[32];
    
    D3D12_ROOT_SIGNATURE_DESC1 root_sig_desc;
    
//    ID3D12PipelineState* pipeline_state;
    
    void SetRootSignatureDesc(ID3D12Device2* device,D12RootSignature* rs,
                              const D3D12_ROOT_SIGNATURE_DESC1& rootSignatureDesc,
                              D3D_ROOT_SIGNATURE_VERSION rootSignatureVersion
                              )
    {
        // Make sure any previously allocated root signature description is cleaned 
        // up first.
        //Destroy();
        
        //auto device = Application::Get().GetDevice();
        
        UINT numParameters = rootSignatureDesc.NumParameters;
        D3D12_ROOT_PARAMETER1* pParameters = numParameters > 0 ? new D3D12_ROOT_PARAMETER1[numParameters] : nullptr;
        
        for (UINT i = 0; i < numParameters; ++i)
        {
            const D3D12_ROOT_PARAMETER1& rootParameter = rootSignatureDesc.pParameters[i];
            pParameters[i] = rootParameter;
            
            if (rootParameter.ParameterType == D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE)
            {
                UINT numDescriptorRanges = rootParameter.DescriptorTable.NumDescriptorRanges;
                D3D12_DESCRIPTOR_RANGE1* pDescriptorRanges = numDescriptorRanges > 0 ? new D3D12_DESCRIPTOR_RANGE1[numDescriptorRanges] : nullptr;
                
                memcpy(pDescriptorRanges, rootParameter.DescriptorTable.pDescriptorRanges,
                       sizeof(D3D12_DESCRIPTOR_RANGE1) * numDescriptorRanges);
                
                pParameters[i].DescriptorTable.NumDescriptorRanges = numDescriptorRanges;
                pParameters[i].DescriptorTable.pDescriptorRanges = pDescriptorRanges;
                
                // Set the bit mask depending on the type of descriptor table.
                if (numDescriptorRanges > 0)
                {
                    switch (pDescriptorRanges[0].RangeType)
                    {
                        case D3D12_DESCRIPTOR_RANGE_TYPE_CBV:
                        case D3D12_DESCRIPTOR_RANGE_TYPE_SRV:
                        case D3D12_DESCRIPTOR_RANGE_TYPE_UAV:
                        desc_table_bitmask|= (1 << i);
                        break;
                        case D3D12_DESCRIPTOR_RANGE_TYPE_SAMPLER:
                        sampler_table_bitmask|= (1 << i);
                        break;
                    }
                }
                
                // Count the number of descriptors in the descriptor table.
                for (UINT j = 0; j < numDescriptorRanges; ++j)
                {
                    num_of_desc_per_table[i] += pDescriptorRanges[j].NumDescriptors;
                }
            }
        }
        
        root_sig_desc.NumParameters = numParameters;
        root_sig_desc.pParameters = pParameters;
        
        UINT numStaticSamplers = rootSignatureDesc.NumStaticSamplers;
        D3D12_STATIC_SAMPLER_DESC* pStaticSamplers = numStaticSamplers > 0 ? new D3D12_STATIC_SAMPLER_DESC[numStaticSamplers] : nullptr;
        
        if ( pStaticSamplers )
        {
            memcpy( pStaticSamplers, rootSignatureDesc.pStaticSamplers,
                   sizeof( D3D12_STATIC_SAMPLER_DESC ) * numStaticSamplers );
        }
        
        root_sig_desc.NumStaticSamplers = numStaticSamplers;
        root_sig_desc.pStaticSamplers = pStaticSamplers;
        
        D3D12_ROOT_SIGNATURE_FLAGS flags = rootSignatureDesc.Flags;
        root_sig_desc.Flags = flags;
        
        CD3DX12_VERSIONED_ROOT_SIGNATURE_DESC versionRootSignatureDesc;
        versionRootSignatureDesc.Init_1_1(numParameters, pParameters, numStaticSamplers, pStaticSamplers, flags);
        
        // Serialize the root signature.
        ID3DBlob* rootSignatureBlob;
        ID3DBlob* errorBlob;
        D3DX12SerializeVersionedRootSignature( &versionRootSignatureDesc,
                                              rootSignatureVersion, &rootSignatureBlob, &errorBlob );
        
        // Create the root signature.
        device->CreateRootSignature(0, rootSignatureBlob->GetBufferPointer(),
                                    rootSignatureBlob->GetBufferSize(), IID_PPV_ARGS(&root_sig.state));
        
        
        
    }
    
/*    
    void InitMipMapsPSO(ID3D12Device2* device)
    {
        D3D12_FEATURE_DATA_ROOT_SIGNATURE featureData = {};
        featureData.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_1;
        if ( FAILED( device->CheckFeatureSupport( D3D12_FEATURE_ROOT_SIGNATURE, &featureData, sizeof( featureData ) ) ) )
        {
            featureData.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_0;
        }
        
        CD3DX12_DESCRIPTOR_RANGE1 srcMip( D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 1, 0, 0, D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE );
        CD3DX12_DESCRIPTOR_RANGE1 outMip( D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 4, 0, 0, D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE );
        
        CD3DX12_ROOT_PARAMETER1 rootParameters[NumRootParameters];
        rootParameters[GenerateMipsCB].InitAsConstants( sizeof( GenerateMipsCB ) / 4, 0 );
        
        rootParameters[SrcMip].InitAsDescriptorTable( 1, &srcMip );
        rootParameters[OutMip].InitAsDescriptorTable( 1, &outMip );
        
        CD3DX12_STATIC_SAMPLER_DESC linearClampSampler( 
            0,
            D3D12_FILTER_MIN_MAG_MIP_LINEAR,
            D3D12_TEXTURE_ADDRESS_MODE_CLAMP,
            D3D12_TEXTURE_ADDRESS_MODE_CLAMP,
            D3D12_TEXTURE_ADDRESS_MODE_CLAMP
            );
        
        CD3DX12_VERSIONED_ROOT_SIGNATURE_DESC rootSignatureDesc( 
            NumRootParameters,
            rootParameters, 1, &linearClampSampler
            );
        
        SetRootSignatureDesc(device,&root_sig, 
                             rootSignatureDesc.Desc_1_1, 
                             featureData.HighestVersion 
                             );
        
        // Create the PSO for GenerateMips shader.
        struct PipelineStateStream
        {
            CD3DX12_PIPELINE_STATE_STREAM_ROOT_SIGNATURE pRootSignature;
            CD3DX12_PIPELINE_STATE_STREAM_CS CS;
        } pipelineStateStream;
        
        char* file_name = "../GenerateMips_CS.hlsl";
        FMJFileReadResult rf_result = fmj_file_platform_read_entire_file(file_name);
        ASSERT(rf_result.content_size > 0);
        
        ID3DBlob* vs_blob;
        ID3DBlob* vs_blob_errors;
        
        HRESULT r = D3DCompile2(
            rf_result.content,
            rf_result.content_size,
            file_name,
            0,
            0,
            "main",
            "cs_5_1",
            SHADER_DEBUG_FLAGS,
            0,
            0,
            0,
            0,
            &vs_blob,
            &vs_blob_errors);
        
        if ( vs_blob_errors )
        {
            OutputDebugStringA( (const char*)vs_blob_errors->GetBufferPointer());
        }
        ASSERT(SUCCEEDED(r));
        
        pipelineStateStream.pRootSignature = root_sig.state;
        pipelineStateStream.CS = { vs_blob, sizeof( vs_blob ) };
        
        D3D12_PIPELINE_STATE_STREAM_DESC pipelineStateStreamDesc = {
            sizeof( PipelineStateStream ), &pipelineStateStream
        };
        
        device->CreatePipelineState( &pipelineStateStreamDesc, IID_PPV_ARGS( &pipeline_state )  );
        
        // Create some default texture UAV's to pad any unused UAV's during mip map generation.
        //m_DefaultUAV = AllocateDescriptors( D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, 4 );
        // Describe and create a render target view (RTV) descriptor heap.
        
        ID3D12DescriptorHeap* d_heap;
        D3D12_DESCRIPTOR_HEAP_DESC dhd = {};
        dhd.NumDescriptors = 4;
        dhd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
        dhd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
        device->CreateDescriptorHeap(&dhd, IID_PPV_ARGS(&d_heap));
        
        uint64_t dhd_size = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        CD3DX12_CPU_DESCRIPTOR_HANDLE dhdhandle(d_heap->GetCPUDescriptorHandleForHeapStart());
        
        for ( UINT i = 0; i < 4; ++i )
        {
            D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc = {};
            uavDesc.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
            uavDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
            uavDesc.Texture2D.MipSlice = i;
            uavDesc.Texture2D.PlaneSlice = 0;
            CD3DX12_CPU_DESCRIPTOR_HANDLE hand = dhdhandle.Offset(i,dhd_size);
            device->CreateUnorderedAccessView( 
                nullptr, nullptr, &uavDesc, 
                hand
                );
        }
    }
*/    

    void Init(ID3D12Device2* device)
    {
        tracker.resource_table = fmj_anycache_init(4096,sizeof(ResourceTableEntry),sizeof(ResourceTableEntryKey),false);
        tracker.sub_resource_table = fmj_anycache_init(4096,sizeof(SubResourceTableEntry),sizeof(SubResourceTableEntryKey),false);
        tracker.pending_resource_barriers = fmj_anycache_init(4096,sizeof(ResourceBarriers),sizeof(ResourceBarriersKey),false);
        per_thread_resource_state.resource_state_vectors = fmj_stretch_buffer_init(MAX_CPU_WORKER_THREADS,sizeof(FMJStretchBuffer),8);


        for(int i = 0;i < MAX_CPU_WORKER_THREADS;++i)
        {
            FMJStretchBuffer* yv = (FMJStretchBuffer*)fmj_stretch_buffer_get_any_(&per_thread_resource_state.resource_state_vectors,i); 
            *yv = fmj_stretch_buffer_init(1,sizeof(D12ResourceStateEntry),8);
        }
        
        //InitMipMapsPSO(device);
        /*
        tracker.resource_table = YoyoInitVector(1,ResourceTableEntry,false);
        tracker.sub_resource_table = YoyoInitVector(1,SubResourceTableEntry,false);
        tracker.pending_resource_barriers = YoyoInitVector(1,ResourceBarriers,false);
    */
    }
    
    void TrackResource(D12CommandListEntry* entry, ID3D12Object* o)
    {
        fmj_stretch_buffer_push(&entry->temp_resources,(void*)o);
    }
    
    void AliasingBarrier(D12CommandListEntry* cl,ID3D12Resource* beforeResource, ID3D12Resource* afterResource)
    {
        auto barrier = CD3DX12_RESOURCE_BARRIER::Aliasing(beforeResource, afterResource);
        
        //m_ResourceStateTracker->ResourceBarrier(barrier);
        cl->list->ResourceBarrier(1, &barrier);
        /*
        if (flushBarriers)
        {
            FlushResourceBarriers();
        }
        */
    }
    
    void AliasingBarrier(D12CommandListEntry* cl,D12Resource beforeResource, D12Resource afterResource)
    {
        AliasingBarrier(cl,beforeResource.state, afterResource.state);
    }
    
    void TransitionBarrier(ID3D12GraphicsCommandList* cl,ID3D12Resource* resource, D3D12_RESOURCE_STATES stateAfter, UINT subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, bool flushBarriers = false)
    {
        if (resource)
        {
            // The "before" state is not important. It will be resolved by the resource state tracker.
            auto barrier = CD3DX12_RESOURCE_BARRIER::Transition(resource, D3D12_RESOURCE_STATE_COMMON, stateAfter, subresource);
            //TODO(Ray):Make this multi thread safe for now we just doint this the stupid way.
            cl->ResourceBarrier(1, &barrier);
            //ResourceBarrier(rt,barrier);
        }
        
        if (flushBarriers)
        {
            //FlushResourceBarriers(rt,cl);
        }
    }
    
    void TransitionBarrier(ID3D12GraphicsCommandList* cl, D12Resource resource, D3D12_RESOURCE_STATES stateAfter, UINT subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, bool flushBarriers = false )
    {
        TransitionBarrier(cl,resource.state, stateAfter, subresource, flushBarriers);
    }
    
    void CopyResource(D12CommandListEntry* cl, ID3D12Resource* dstRes, ID3D12Resource* srcRes)
    {
        TransitionBarrier(cl->list,dstRes, D3D12_RESOURCE_STATE_COPY_DEST);
        TransitionBarrier(cl->list,srcRes, D3D12_RESOURCE_STATE_COPY_SOURCE);
        //FlushResourceBarriers();
        
        cl->list->CopyResource(dstRes, srcRes);
        
        TrackResource(cl,dstRes);
        TrackResource(cl,srcRes);
    }
    
    void CopyResource(D12CommandListEntry* cl,D12Resource dstRes, D12Resource srcRes )
    {
        CopyResource(cl,dstRes.state, srcRes.state);
    }
    
    bool IsSRGBFormat(DXGI_FORMAT format)
    {
        switch (format)
        {
            case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
            case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
            case DXGI_FORMAT_B8G8R8X8_UNORM_SRGB:
            return true;
            default:
            return false;
        }
    }
    
    DXGI_FORMAT GetSRGBFormat(DXGI_FORMAT format)
    {
        DXGI_FORMAT srgbFormat = format;
        switch ( format )
        {
            case DXGI_FORMAT_R8G8B8A8_UNORM:
            srgbFormat = DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
            break;
            case DXGI_FORMAT_BC1_UNORM:
            srgbFormat = DXGI_FORMAT_BC1_UNORM_SRGB;
            break;
            case DXGI_FORMAT_BC2_UNORM:
            srgbFormat = DXGI_FORMAT_BC2_UNORM_SRGB;
            break;
            case DXGI_FORMAT_BC3_UNORM:
            srgbFormat = DXGI_FORMAT_BC3_UNORM_SRGB;
            break;
            case DXGI_FORMAT_B8G8R8A8_UNORM:
            srgbFormat = DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
            break;
            case DXGI_FORMAT_B8G8R8X8_UNORM:
            srgbFormat = DXGI_FORMAT_B8G8R8X8_UNORM_SRGB;
            break;
            case DXGI_FORMAT_BC7_UNORM:
            srgbFormat = DXGI_FORMAT_BC7_UNORM_SRGB;
            break;
        }
        
        return srgbFormat;
    }
    
    void SetShaderResourceView(D12CommandListEntry* cl_entry, uint32_t rootParameterIndex,
                               uint32_t descriptorOffset,
                               const D12Resource* resource,
                               D3D12_RESOURCE_STATES stateAfter,
                               UINT firstSubresource,
                               UINT numSubresources,
                               const D3D12_SHADER_RESOURCE_VIEW_DESC* srv)
    {
        if (numSubresources < D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES)
        {
            for (uint32_t i = 0; i < numSubresources; ++i)
            {
                TransitionBarrier(cl_entry->list,resource->state, stateAfter, firstSubresource + i);
            }
        }
        else
        {
            TransitionBarrier(cl_entry->list,resource->state, stateAfter);
        }
        
        //m_DynamicDescriptorHeap[D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV]->StageDescriptors(rootParameterIndex, descriptorOffset, 1, resource.GetShaderResourceView(srv) );
        
        TrackResource(cl_entry,resource->state);
    }
};
